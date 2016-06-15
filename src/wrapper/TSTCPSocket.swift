import Foundation
import lwip

/**
 The delegate that developer should implement to handle various TCP events.
 */
public protocol TSTCPSocketDelegate: class {
    /**
     The socket is closed on tx side (FIN received). We will not read any data.
     */
    func localDidClose(socket: TSTCPSocket)

    /**
     The socket is reseted (RST received), it should be released immediately.
     */
    func socketDidReset(socket: TSTCPSocket)

    /**
     The socket is aborted (RST sent), it should be released immediately.
     */
    func socketDidAbort(socket: TSTCPSocket)

    /**
     The socket is closed. This will only be triggered if the socket is closed actively by calling `close()`. It should be released immediately.
     */
    func socketDidClose(socket: TSTCPSocket)


    /**
     Socket read data from local tx side.

     - parameter data: The read data.
     - parameter from: The socket object.
     */
    func didReadData(data: NSData, from: TSTCPSocket)

    /**
     The socket has sent the specific length of data.

     - parameter length: The length of data being ACKed.
     - parameter from:   The socket.
     */
    func didWriteData(length: Int, from: TSTCPSocket)
}

// There is no way the error will be anything but ERR_OK, so the `error` parameter should be ignored.
func tcp_recv_func(arg: UnsafeMutablePointer<Void>, pcb: UnsafeMutablePointer<tcp_pcb>, buf: UnsafeMutablePointer<pbuf>, error: err_t) -> err_t {
    guard let socket = SocketDict.lookup(UnsafeMutablePointer<SocketIdentity>(arg).memory) else {
        // we do not know what this socket is, abort it
        tcp_abort(pcb)
        return err_t(ERR_ABRT)
    }
    socket.recved(buf)
    return err_t(ERR_OK)
}

func tcp_sent_func(arg: UnsafeMutablePointer<Void>, pcb: UnsafeMutablePointer<tcp_pcb>, len: UInt16) -> err_t {
    guard let socket = SocketDict.lookup(UnsafeMutablePointer<SocketIdentity>(arg).memory) else {
        // we do not know what this socket is, abort it
        tcp_abort(pcb)
        return err_t(ERR_ABRT)
    }
    socket.sent(Int(len))
    return err_t(ERR_OK)
}

func tcp_err_func(arg: UnsafeMutablePointer<Void>, error: err_t) {
    SocketDict.lookup(UnsafeMutablePointer<SocketIdentity>(arg).memory)?.errored(error)
}

struct SocketDict {
    static var socketDict: [SocketIdentity:TSTCPSocket] = [:]

    static func lookup(id: SocketIdentity) -> TSTCPSocket? {
        return socketDict[id]
    }
}

struct SocketIdentity: Hashable {
    let id: Int

    var hashValue: Int {
        return id
    }
}

func ==(left: SocketIdentity, right: SocketIdentity) -> Bool {
    return left.id == right.id
}

/**
 The TCP socket class.

 - note: Unless one of `socketDidReset`, `socketDidAbort` or `socketDidClose` delegation methods is called, please do `close()`the socket actively and wait for `socketDidClose` before releasing it.
 */
public final class TSTCPSocket {
    private var pcb: UnsafeMutablePointer<tcp_pcb>
    /// The source IPv4 address.
    public let sourceAddress: in_addr
    /// The destination IPv4 address
    public let destinationAddress: in_addr
    /// The source port.
    public let sourcePort: UInt16
    /// The destination port.
    public let destinationPort: UInt16
    let queue: dispatch_queue_t
    private var identity: SocketIdentity

    var isValid: Bool {
        return pcb != nil
    }

    /// Whether the socket is connected (we can receive and send data).
    public var connected: Bool {
        return isValid && pcb.memory.state.rawValue >= ESTABLISHED.rawValue && pcb.memory.state.rawValue < CLOSED.rawValue
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
        SocketDict.socketDict[identity] = self

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

    func recved(buf: UnsafeMutablePointer<pbuf>) {
        if buf == nil {
            delegate?.localDidClose(self)
        } else {
            let data = NSMutableData(length: Int(buf.memory.tot_len))!
            pbuf_copy_partial(buf, data.mutableBytes, buf.memory.tot_len, 0)
            delegate?.didReadData(data, from: self)
            tcp_recved(pcb, buf.memory.tot_len)
            pbuf_free(buf)
        }
    }

    /**
     Send data to local rx side.

     - parameter data: The data to send.

     - returns: Whether the data is queued successfully. Currently, this method will only fail when the socket is already closed.
     */
    public func writeData(data: NSData) -> Bool {
        // Note this is called synchronously since we need the result of `tcp_write()` and `tcp_write()` just puts the packets on the queue without sending them, so we can get the result immediately.
        var result = false
        dispatch_sync(queue) {
            guard self.isValid else {
                result = false
                return
            }

            let err = tcp_write(self.pcb, data.bytes, UInt16(data.length), UInt8(TCP_WRITE_FLAG_COPY))
            if  err != err_t(ERR_OK) {
                result = false
            } else {
                result = true
            }

        }
        return result
    }

    /**
     Close the socket. The socket should be released immediately and should not be read or write again.
     */
    public func close() {
        dispatch_async(queue) {
            guard self.isValid else {
                return
            }

            tcp_close(self.pcb)
            self.release()
            // the lwip will handle the following things for us
            self.delegate?.socketDidClose(self)
        }
    }

    func release() {
        pcb = nil
    }

    deinit {
        SocketDict.socketDict.removeValueForKey(identity)
    }
}
