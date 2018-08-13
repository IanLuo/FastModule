//
//  String+Match.swift
//  Alamofire
//
//  Created by ian luo on 24/02/2018.
//

import Foundation

extension String {
    internal mutating func extractEmbededURL() -> [String: String] {
        do {
            let regex = try NSRegularExpression(pattern: "(#url[0-9]*)\\((.*?)\\)", options: [])
            let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            
            var result: [String: String] = [:]
            var keys: [String] = []
            var urls: [String] = []

            matches.forEach { match in
                for n in 1..<match.numberOfRanges {
                    let range = match.range(at: n)
                    if n % 2 != 0 {
                        keys.append((self as NSString).substring(with: range))
                    } else {
                        urls.append((self as NSString).substring(with: range))
                    }
                }
            }
            
            guard keys.count == urls.count else { return [:] }
            
            for (index, url) in urls.enumerated() {
                result[keys[index]] = url
                self.replaceSubrange(self.range(of: "(\(url))")!, with: "")
            }
            return result
        } catch {
            return [:]
        }
    }
    
    /// for example: /some-action/:param1/:param2
    internal var bindingActionPattern: String {
        var regexPattern = self.components(separatedBy: "/")
            .map { (item: String) -> String in
                if item.hasPrefix(":") {
                    return "([#a-zA-Z0-9:\\-_\\.\\, ]+)"
                } else {
                    return item
                }
            }.reduce("") {  last, next in
                return last + "/" + next
        }
        
        regexPattern.removeFirst()
        
        return "^\(regexPattern)$"
    }

    /// for example: /some-action/#param1/#param2
    internal var requestActionPattern: String {
        var regexPattern = self.components(separatedBy: "/")
            .map { (item: String) -> String in
                if item.hasPrefix("#") {
                    return "([#a-zA\\-Z0-9:-_ ]+)"
                } else {
                    return item
                }
            }.reduce("") {  last, next in
                return last + "/" + next
        }
        
        regexPattern.removeFirst()
        
        return "^\(regexPattern)$"
    }
    
    internal func matchActionBinding(string: String) -> Bool {
        do {
            let matches = try NSRegularExpression(pattern: bindingActionPattern, options: [.anchorsMatchLines]).matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            return matches.count > 0
        } catch {
            return false
        }
    }
    
    internal var requestPatternKeys: [String] {
        do {
            let matches = try NSRegularExpression(pattern: requestActionPattern, options: [.anchorsMatchLines]).matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            
            var result: [String] = []
            matches.forEach { match in
                for n in 1..<match.numberOfRanges {
                    result.append((self as NSString).substring(with: match.range(at: n)))
                }
            }
            return result
        } catch {
            return []
        }
    }
    
    internal var bindingPatternKeys: [String] {
        do {
            let matches = try NSRegularExpression(pattern: bindingActionPattern, options: []).matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            
            var result: [String] = []
            matches.forEach { match in
                for n in 1..<match.numberOfRanges {
                    result.append((self as NSString).substring(with: match.range(at: n)))
                }
            }
            return result
        } catch {
            return []
        }
    }
    
    internal func extractBindingValues(binding: String) -> [Any] {
        do {
            let matches = try NSRegularExpression(pattern: binding.bindingActionPattern, options: [.anchorsMatchLines]).matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            
            var result: [String] = []
            matches.forEach { match in
                for n in 1..<match.numberOfRanges {
                    result.append((self as NSString).substring(with: match.range(at: n)))
                }
            }
            return result
        } catch {
            return []
        }
    }
}
