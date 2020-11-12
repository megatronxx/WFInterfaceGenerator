import Foundation

protocol WFInterfaceParameter {
    var nameInfo:[String:String]{get set}
    var requires:[String]{get set}
    var params:[String]{get set}
    
}
extension WFInterfaceParameter {
    //参数自检
    func check(callback:@escaping ((_ res:Bool, _ key:String, _ name:String)->())) {
        
        for k in requires {
            let sks = Mirror(reflecting: self).children
            let tkvs = sks.filter{ return $0.label == k }
            guard let kv = tkvs.first else {
                callback(false,k,"\(nameInfo[k] ?? "参数")")
                return
            }
            if "\(kv.value)".count <= 0 {
                callback(false,k,"\(nameInfo[k] ?? "参数")")
                return
            }
        }
        callback(true,"","")
    }
}

protocol WFInterface {
    var link:String{get set}
    /**
     请求方式:
     0 - get
     1 - post
     3 - 文件上传
     */
    var method:Int{get set}
    var param:WFInterfaceParameter?{get set}
}

struct WFInterfaceGenerator {
    var text:String = "接口参数生成器"
    //接口文件路径
    var interfaceListPath:String = ""
    //输出文件路径
    var outModelPath:String = ""
    
}
extension WFInterfaceGenerator {
    //开工
    func start() {
        if interfaceListPath.count <= 0 || outModelPath.count <= 0 {
            print("请完善路径")
            return
        }else{
            let arr = getInterfaces()
            requestGenerate(arr: arr)
        }
    }
    
    //获取接口列表
    func getInterfaces() -> Array<NSDictionary> {
        if FileManager.default.fileExists(atPath: interfaceListPath) {
            let arr = NSArray(contentsOfFile: interfaceListPath) as! [NSDictionary]
            return arr
        }else{
            print("接口文件不存在")
            return []
        }
    }
    //获取接口结构体末班
    func getInterfaceTmp() -> String {
        let res =
            """
            import Foundation

            struct __name__ : WFInterface {
                var link: String = "__link__"
                var method: Int = __method__
                var param:WFInterfaceParameter?
            }
            """
        
        return res
    }
    //获取参数结构体末班
    func getParamTmp() -> String {
        let res =
            """
            import Foundation

            struct __name__ : WFInterfaceParameter {
                var nameInfo:[String:String] = [__nameInfo__]
                var requires:[String] = [__requires__]
                var params:[String] = [__params__]
                
                __propertys__
            }

            """
        
        return res
    }
    
    //根据接口列表生成（接口索引文件，接口文件，参数文件）
    func requestGenerate(arr:[NSDictionary]) {
        let ifdic = interfaceListPath + "/interfaces"
        let ipdic = interfaceListPath + "/params"
        if !FileManager.default.fileExists(atPath: ifdic, isDirectory: UnsafeMutablePointer(bitPattern: 1)) {
           try? FileManager.default.createDirectory(atPath: ifdic, withIntermediateDirectories: false, attributes: nil)
        }
        if !FileManager.default.fileExists(atPath: ipdic, isDirectory: UnsafeMutablePointer(bitPattern: 1)) {
           try? FileManager.default.createDirectory(atPath: ipdic, withIntermediateDirectories: false, attributes: nil)
        }
        for d in arr {
            createIFile(dic: d)
            createPFile(dic: d)
        }
    }
    //根据字典创建接口文件
    func createIFile(dic:NSDictionary) {
        let ifdic = interfaceListPath + "/interfaces"
        
        let name = "\(dic["name"] ?? "")"
        let link = "\(dic["link"] ?? "")"
        let method = "\(dic["method"] ?? "0")"
        
        let ifname = "interface_\(name)"
        var itmp = getInterfaceTmp()
        itmp = (itmp as NSString).replacingOccurrences(of: "__name__", with: ifname)
        itmp = (itmp as NSString).replacingOccurrences(of: "__link__", with: link)
        itmp = (itmp as NSString).replacingOccurrences(of: "__method__", with: method)
        let idata = itmp.data(using: .utf8)!
        let ifpath = ifdic + "/" + ifname + ".swift"
        if !FileManager.default.fileExists(atPath: ifpath) {
            FileManager.default.createFile(atPath: ifpath, contents: idata, attributes: nil)
        }else{
            try? idata.write(to: URL(fileURLWithPath: ifpath))
        }
    }
    //根据字典创建参数文件
    func createPFile(dic:NSDictionary) {
        let ipdic = interfaceListPath + "/params"
        
        let name = "\(dic["name"] ?? "")"
        let param = dic["param"] as! [NSDictionary]
        
        let pfname = "param_\(name)"
        var ptmp = getParamTmp()
        ptmp = (ptmp as NSString).replacingOccurrences(of: "__name__", with: pfname)
        
        //键名
        var nameInfo:[String:String] = [:]
        //必填
        var requires:[String] = []
        //全部
        var params:[String] = []
        
        for p in param {
            let key = "\(p["key"] ?? "")"
            let name = "\(p["name"] ?? "")"
            let required = "\(p["required"] ?? "0")"
            
            //键名
            nameInfo[key] = name
            //必填
            if required == "1" {
                requires.append(key)
            }
            //全部
            params.append(key)
        }
        let p:String = params.joined(separator: ",") + ":String = \"\""
        ptmp = (ptmp as NSString).replacingOccurrences(of: "__nameInfo__", with: nameInfo.toString())
        ptmp = (ptmp as NSString).replacingOccurrences(of: "__requires__", with: requires.toString())
        ptmp = (ptmp as NSString).replacingOccurrences(of: "__params__", with: params.toString())
        ptmp = (ptmp as NSString).replacingOccurrences(of: "__propertys__", with: p)
        
        let pdata = ptmp.data(using: .utf8)!
        let pfpath = ipdic + "/" + pfname + ".swift"
        if !FileManager.default.fileExists(atPath: pfpath) {
            FileManager.default.createFile(atPath: pfpath, contents: pdata, attributes: nil)
        }else{
            try? pdata.write(to: URL(fileURLWithPath: pfpath))
        }
    }
}

extension Dictionary {
    func toString() -> String {
        if (!JSONSerialization.isValidJSONObject(self)) {
            print("无法解析出JSONString")
            return ""
        }
        let data : NSData! = try? JSONSerialization.data(withJSONObject: self, options: []) as NSData
        
        let JSONString = NSString(data:data as Data,encoding: String.Encoding.utf8.rawValue)
        return JSONString! as String
    }
}
extension Array {
    func toString() -> String {
        if (!JSONSerialization.isValidJSONObject(self)) {
            print("无法解析出JSONString")
            return ""
        }
        let data : NSData! = try? JSONSerialization.data(withJSONObject: self, options: []) as NSData
        
        let JSONString = NSString(data:data as Data,encoding: String.Encoding.utf8.rawValue)
        return JSONString! as String
    }
}
