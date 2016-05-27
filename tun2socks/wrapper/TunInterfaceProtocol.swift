import Foundation

public protocol TunInterfaceProtocol {
    func readPackets(completionHandler: ([NSData]) -> ())
    func writePackets(packets: [NSData], versions: [Int])
}
