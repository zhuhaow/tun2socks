import Foundation
import lwip

/// The delegate that the developer should implement to handle what to do when a new TCP socket is connected.
public protocol TSIPStackDelegate: class {
    func didAcceptTCPSocket(sock: TSTCPSocket)
}

func tcpAcceptFn(arg: UnsafeMutablePointer<Void>, pcb: UnsafeMutablePointer<tcp_pcb>, error: err_t) -> err_t {
    return TSIPStack.stack.didAcceptTCPSocket(pcb, error: error)
}

func outputPCB(interface: UnsafeMutablePointer<netif>, buf: UnsafeMutablePointer<pbuf>, ipaddr: UnsafeMutablePointer<ip_addr_t>) -> err_t {
    TSIPStack.stack.writePBuf(buf)
    return err_t(ERR_OK)
}

/// This is the IP stack that receives and outputs IP packets.
public class TSIPStack {
    public static var stack = TSIPStack()

    // The whole stack is running in this dispatch queue.
    let processQueue = dispatch_queue_create("tun2socks.IPStackQueue", DISPATCH_QUEUE_SERIAL)!

    let timer: dispatch_source_t
    let listenPCB: UnsafeMutablePointer<tcp_pcb>

    public var outputBlock: (([NSData], [NSNumber]) -> ())!

    public weak var delegate: TSIPStackDelegate?

    // Since all we need is a mock interface, we just use the loopback interface provided by lwip.
    // Do not need to add any interface.
    var interface: UnsafeMutablePointer<netif> {
        return netif_list
    }

    private init() {
        lwip_init()

        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, processQueue)

        // add a listening pcb
        var pcb = tcp_new()
        var addr = ip_addr_any
        tcp_bind(pcb, &addr, 0)
        pcb = tcp_listen_with_backlog(pcb, UInt8(TCP_DEFAULT_LISTEN_BACKLOG))
        listenPCB = pcb
        tcp_accept(pcb, tcpAcceptFn)

        interface.memory.output = outputPCB

        // note the default tcp_tmr interval is 250 ms.
        // I don't know the best way to set leeway.
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 4, NSEC_PER_SEC / 4)
        dispatch_source_set_event_handler(timer) {
            [weak self] in
            self?.checkTimeout()
        }
        dispatch_resume(timer)
    }

    private func checkTimeout() {
        sys_check_timeouts()
    }

    func dispatch_call(block: () -> ()) {
        dispatch_async(processQueue, block)
    }

    /**
     Suspend the timer. The timer should be suspended when the device is going to sleep.
     */
    public func suspendTimer() {
        dispatch_suspend(timer)
    }

    /**
     Resume the timer when the device is awoke.

     - note: Do not call this unless you suspend the timer, the timer starts automatically when the stack initializes.
     */
    public func resumeTimer() {
        dispatch_call {
            sys_restart_timeouts()
            dispatch_resume(self.timer)
        }
    }

    public func receivedPacket(data: NSData) {
        dispatch_call {
            // Due to the limitation of swift, if we want a zero-copy implemention, we have to change the definition of `pbuf.payload` to `const`, which is not possible.
            // So we have to copy the data anyway.
            let buf = pbuf_alloc(PBUF_RAW, UInt16(data.length), PBUF_RAM)
            data.getBytes(buf.memory.payload, length: data.length)

            // The `netif->input()` should be ip_input(). According to the docs of lwip, we do not pass packets into the `ip_input()` function directly.
            netif_list.memory.input(buf, self.interface)
        }
    }

    func writePBuf(buf: UnsafeMutablePointer<pbuf>) {
        let data = NSMutableData(length: Int(buf.memory.tot_len))!
        pbuf_copy_partial(buf, data.mutableBytes, buf.memory.tot_len, 0)
        // Only support IPv4 as of now.
        outputBlock([data], [Int(AF_INET)])
    }

    func didAcceptTCPSocket(pcb: UnsafeMutablePointer<tcp_pcb>, error: err_t) -> err_t {
        tcp_accepted_c(listenPCB)
        delegate?.didAcceptTCPSocket(TSTCPSocket(pcb: pcb, queue: processQueue))
        return err_t(ERR_OK)
    }
}
