import UIKit

let result: Result<Response<JSONNode>> = "https://api.github.com/repos/keefmoon/JSONNode".fetch()
let avatarURL: String? = result.response?.body?.dictionary?["owner"]?.dictionary?["avatar_url"]?.string

let avatar: UIImage? = avatarURL?.fetch().response?.body
