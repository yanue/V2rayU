import Foundation

protocol BaseShareUri {
    // 从ProfileModel初始化
    init(from model: ProfileEntity)

    // 转换为 String, 用于分享
    func encode() -> String

     // 从URL解析. 返回错误信息
    func parse(url: URL) -> Error?

    // 返回ProfileModel
    func getProfile() -> ProfileEntity
}
