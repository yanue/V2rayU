//
// Created by yanue on 2018/11/21.
// Copyright (c) 2018 yanue. All rights reserved.
//
// link: https://github.com/codinn/SystemProxySettingsDemo

import Foundation
import ServiceManagement

struct AuthorizationRightKey {
    static let rightName = "authRightName"
    static let rightDefaultRule = "authRightDefault"
    static let rightDescription = "authRightDescription"
}

class CommonAuthorization: NSObject {

    static let systemProxyAuthRightName = "net.yanue.V2rayU.rights"

    // singleton instance
    static let shared = CommonAuthorization()

    func commandInfo() -> Dictionary<String, Any> {

        // Set up the authorization rule
        // The defaultRights can be either a String or a custom dictionary. I'm using a custom dictionary below, if changing to a string constant, you need to change the cast in setupAuthorizationRights, see the mark.
        // List of defaultRights constants: https://developer.apple.com/reference/security/1669767-authorization_services_c/1670045-policy_database_constants?language=objc

        let ruleAdminRightsExtended: [String:Any] = [
            "key" : CommonAuthorization.systemProxyAuthRightName,
            "class" : "user",
            "group" : "admin",
            // Timeout defines how long the authorization is valid until the user need to authorize again.
            // 0 means authorize every time, and to remove it like this makes it never expire until the AuthorizationRef is destroyed.
            // "timeout" : 0,
            "version" : 1 ]

        // Define all authorization right definitions this application will use.
        // These will be added to the authorization database to then be used by the Security system to verify authorization of each command
        // The format of this dict is:
        //  key == the command selector as string
        //  value == Dictionary containing:
        //    rightName == The name of the authorization right definition
        //    rightDefaultRule == The rule to decide if the user is authorized for this definition
        //    rightName == The Description is the text that will be shown to the user if prompted by the Security system

        // kAuthorizationRuleClassAllow

        let sCommandInfo: [String:Dictionary<String,Any>] =
                [
                    "system_proxy_set":
                    [AuthorizationRightKey.rightName : CommonAuthorization.systemProxyAuthRightName,
                     AuthorizationRightKey.rightDefaultRule : ruleAdminRightsExtended,
                     AuthorizationRightKey.rightDescription : "Codinn App want to change system proxy settings."]
                ]
        return sCommandInfo
    }

    /*
     Adds or updates all authorization right definitions to the authorization database
     */
    func setupAuthorizationRights(authRef: AuthorizationRef) -> Void {

        // Enumerate through all authorization right definitions and check them one by one against the authorization database
        self.enumerateAuthorizationRights(right: {
            rightName, rightDefaultRule, rightDescription in

            var status:OSStatus
            var currentRight:CFDictionary?

            // Try to get the authorization right definition from the database
            status = AuthorizationRightGet((rightName as NSString).utf8String! , &currentRight)
            Swift.print("AuthorizationRightGet with: right name[\(rightName)], result[\(status)]")

            if (status == errAuthorizationDenied) {

                // If not found, add or update the authorization entry in the database
                // MARK: Change "rightDefaultRule as! CFDictionary" to "rightDefaultRule as! CFString" if changing defaultRule to string
                // rightDefaultRule as! CFDictionary
                // kAuthorizationRuleAuthenticateAsAdmin as! CFString
                // kAuthorizationRuleAuthenticateAsSessionUser
                // kAuthorizationRuleIsAdmin
                // kAuthorizationRuleClassAllow
                // kAuthorizationRightRule
                status = AuthorizationRightSet(authRef, (rightName as NSString).utf8String!, rightDefaultRule as! CFDictionary, rightDescription as CFString, nil, "Common" as CFString)

                Swift.print("AuthorizationRightSet set Policy Database with: right name[\(rightName)], result[\(status)]")
            }

            if (status != errAuthorizationSuccess) {
                let errorMessage = SecCopyErrorMessageString(status, nil)

                // This error is not really handled, shoud probably return it to let the caller know it failed.
                // This will not be printed in the Xcode console as this function is called from the helper.
                Swift.print(errorMessage ?? "Error adding authorization right: \(rightName)")
            }
        })
    }

    /*
     Convenience to enumerate all right definitions by returning each right's name, description and default
     */
    func enumerateAuthorizationRights(right: (_ rightName: String, _ rightDefaultRule: Any, _ rightDescription: String) -> ()) {

        // Loop through all authorization right definitions
        for commandInfoDict in self.commandInfo().values {

            // FIXME: There is no error handling here, other than returning early if it fails. That should be added to better find possible errors.

            guard let commandDict = commandInfoDict as? Dictionary<String, Any> else { return }
            guard let rightName = commandDict[AuthorizationRightKey.rightName] as? String else { return }
            guard let rightDescription = commandDict[AuthorizationRightKey.rightDescription] as? String else { return }
            let rightDefaultRule = commandDict[AuthorizationRightKey.rightDefaultRule] as Any

            // Use the supplied block code to return the authorization right definition Name, Default, and Description
            right(rightName, rightDefaultRule, rightDescription)
        }
    }
}
