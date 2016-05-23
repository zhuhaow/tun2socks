import Foundation

public protocol TunInterfaceProtocol {
    func readPackets(completionHandler: ([NSData]?, NSError?) -> ())
    func writePackets(packets: [NSData])
}
