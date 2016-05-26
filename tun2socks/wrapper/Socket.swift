import Foundation
import lwip

public protocol TSTCPSocketDelegate: class {
    func localDidClose(socket: TSTCPSocket)
    func socketDidReset(socket: TSTCPSocket)
    func socketDidAbort(socket: TSTCPSocket)
    func socketDidClose(socket: TSTCPSocket)
    func didReadData(data: NSData, from: TSTCPSocket)
    func didWriteData(length: Int, from: TSTCPSocket)
}

// There is no way the error will be anything but ERR_OK, so the error parameter should be ignored.
func tcp_recv_func(arg: UnsafeMutablePointer<Void>, pcb: UnsafeMutablePointer<tcp_pcb>, buf: UnsafeMutablePointer<pbuf>, error: err_t) -> err_t {
    let socket = SocketDict.lookup(UnsafeMutablePointer<SocketIdentity>(arg).memory)
    socket?.recved(buf, error: error)
    tcp_recved(pcb, buf.memory.tot_len)
    pbuf_free(buf)
    return err_t(ERR_OK)
}

func tcp_sent_func(arg: UnsafeMutablePointer<Void>, pcb: UnsafeMutablePointer<tcp_pcb>, len: UInt16) -> err_t {
    SocketDict.lookup(UnsafeMutablePointer<SocketIdentity>(arg).memory)?.sent(Int(len))
    return err_t(ERR_OK)
}

func tcp_err_func(arg: UnsafeMutablePointer<Void>, error: err_t) {
    SocketDict.lookup(UnsafeMutablePointer<SocketIdentity>(arg).memory)?.errored(error)
}

class SocketDict {
    static var socketDict = [Int:TSTCPSocket]()

    static func lookup(id: SocketIdentity) -> TSTCPSocket? {
        return socketDict[id.id]
    }
}

struct SocketIdentity {
    let id: Int
}

public class TSTCPSocket {
    private var pcb: UnsafeMutablePointer<tcp_pcb>
    public let sourceAddress: in_addr
    public let destinationAddress: in_addr
    public let sourcePort: UInt16
    public let destinationPort: UInt16
    let queue: dispatch_queue_t
    private var identity: SocketIdentity

    var invalid: Bool {
        return pcb == nil
    }

    public var connected: Bool {
        return !invalid && pcb.memory.state.rawValue >= ESTABLISHED.rawValue && pcb.memory.state.rawValue < CLOSED.rawValue
    }

    public weak var delegate: TSTCPSocketDelegate?

    init(pcb: UnsafeMutablePointer<tcp_pcb>, queue: dispatch_queue_t) {
        self.pcb = pcb
        self.queue = queue

        // see comments in "lwip/src/core/ipv4/ip.c"
        sourcePort = pcb.memory.remote_port
        destinationPort = pcb.memory.local_port
        sourceAddress = in_addr(s_addr: pcb.memory.remote_ip.addr)
        destinationAddress = in_addr(s_addr: pcb.memory.local_ip.addr)

        identity = SocketIdentity(id: pcb.hashValue)
        SocketDict.socketDict[identity.id] = self

        withUnsafeMutablePointer(&identity) {
            tcp_arg(pcb, UnsafeMutablePointer<Void>($0))
        }
        tcp_recv(pcb, tcp_recv_func)
        tcp_sent(pcb, tcp_sent_func)
        tcp_err(pcb, tcp_err_func)
    }

    func errored(error: err_t) {
        release()
        switch Int32(error) {
        case ERR_RST:
            delegate?.socketDidReset(self)
        case ERR_ABRT:
            delegate?.socketDidAbort(self)
        default:
            break
        }
    }

    func sent(length: Int) {
        delegate?.didWriteData(length, from: self)
    }

    func recved(buf: UnsafeMutablePointer<pbuf>, error: err_t) {
        if buf == nil {
            delegate?.localDidClose(self)
        } else {
            let data = NSMutableData(length: Int(buf.memory.tot_len))!
            pbuf_copy_partial(buf, data.mutableBytes, buf.memory.tot_len, 0)
            delegate?.didReadData(data, from: self)
        }
    }

    public func writeData(data: NSData) -> Bool {
        // note this is called synchronously since we need the result of tcp_write() and tcp_write() just puts the packets on the queue without sending them.
        var result = false
        dispatch_sync(queue) {
            if !self.invalid {
                result = false
                return
            }

            if tcp_write(self.pcb, data.bytes, UInt16(data.length), UInt8(TCP_WRITE_FLAG_COPY)) != err_t(ERR_OK) {
                result = false
            } else {
                result = true
            }

        }
        return result
    }

    public func close() {
        tcp_close(pcb)
        release()
        // the lwip will handle the following things for us
        delegate?.socketDidClose(self)
    }

    func release() {
        pcb = nil
    }

    deinit {
        SocketDict.socketDict.removeValueForKey(identity.id)
    }
}
