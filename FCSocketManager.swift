//
//  FCSocketManager.swift
//
//  Created by Ji.finup on 2020/11/18.
//

import Starscream

protocol FCSocketDelegate {
    func didConnected()
}

class FCSocketModel: NSObject {
    /// 싱글톤
    static let shared: FCSocketModel = FCSocketModel()
    
    /// 소켓 데이터가 로드 여부 논리값
    var isLoadSocketData:Bool = false
    
    /// 명칭
    var Name:String = ""
    /// 실행중이라면 1
    var IsRunning:String = ""
    /// Host URL
    var HostUrl:String = ""
    /// 연결 할 웹 소켓의 URL
    var WebSocketUrl:String = ""
    /// 웹 소켓 서버 시작 시간
    var LatestStartTime:String = ""
    /// 웹 소켓 서버 종료 시간
    var LatestStopTime:String = ""
    /// 클래스 명칭
    var className = String(describing: type(of: self))
    
    /**
     # 설명
     Json형식의 String을 받아서 Dictionary로 변환한 후 변수에 값을 넣어준다.
     
     - Parameters:
        - jsonString: Json형식의 String
     */
    func setData(jsonString:String) {
        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
                self.isLoadSocketData = false
                throw FinupError.ApiDataParseError(className: className, funcName: #function)
            }
            guard let dictionary:Dictionary<String,Any> = try! JSONSerialization.jsonObject(with: jsonData, options: .mutableLeaves) as? Dictionary else {
                self.isLoadSocketData = false
                throw FinupError.ApiDataParseError(className: className, funcName: #function)
            }
            
            self.Name = (dictionary["Name"] as? String) ?? ""
            self.HostUrl = (dictionary["HostUrl"] as? String) ?? ""
            self.WebSocketUrl = (dictionary["WebSocketUrlGet"] as? String) ?? ""
            
            self.isLoadSocketData = true
        } catch {
            let logMsg =  className + ":" + #function
            sendLogMessage(error: error, defaultFname:logMsg)
        }
    }
}

class FCSocketManager: NSObject, WebSocketDelegate {
    /// 싱글톤
    static let shared: FCSocketManager = FCSocketManager()
    /// 델레게이트
    var delegate: FCSocketDelegate?
    /// 웹 소켓
    var socket: WebSocket?
    /// 클래시 명칭
    var className = String(describing: type(of: self))
    /// 현재 소켓에 연결 되어 있는지 여부
    var isConnected = false
    /// disconnect시 재시도 할 것인지
    var retryConnect: Bool = false
    /// 핑 전송 횟수
    var pingCount: Int = 0
    /// 핑퐁 타이머
    var pingTimer: Timer? = nil
    /// 핑퐁 성공 여부
    var isSuccessPing: Bool = true
    /// 재시도 얼럿
    var reconnectAlert: UIAlertController? = nil
    
    var debugSocketStatus:String = ""
    var debugPingCount:Int = 0
    var debugLastPingDate:String = ""
    var debugPingFailCount:Int = 0
    var debugLastPingFailDate:String = ""
    var debugConnectFailCount:Int = 0
    
    /**
     # 설명
     소켓의 초기값을 설정한다.
     */
    func socketInit() {
        let urlString = SOCKET_CONNECT_ADDR + "?Auth=\(MemberStockPoint.shared.getJwt())"
        guard let url = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        
        self.socket = WebSocket(request: request, certPinner: FoundationSecurity(allowSelfSigned: true))
        self.socket?.delegate = FCSocketManager.shared
        self.socket?.respondToPingWithPong = false
    }
    
    func redrawDebugPanel () {
        if appDelegate.serverType.lowercased() != "real" {
            if MessageReceiveController.shared.chatListViewController != nil {
                MessageReceiveController.shared.chatListViewController?.debugPanelUpdate()
            }
        }
    }
    
    /**
     # 기능
     입장중, 입장 가능, 모든 채팅방 리스트의 데이터를 받아오는 함수.
     
     - parameters:
        - handler: API완료 핸들러
     */
    func apiloadSocketRouter(handler: @escaping ServiceEscapingBoolHandler) {
        socketInit()
        handler(true)
//        FCSocketApi().sendRequest(url: SOCKET_ADDR, method: .post) { [self] (dic) in
//            do {
//                guard let resultString = dic[FinupApiString.resultString.rawValue] as? String else {
//                    handler(false)
//                    throw FinupError.ApiDataParseError(className: className, funcName:#function)
//                }
//
//                FCSocketModel.shared.setData(jsonString: resultString)
//                socketInit()
//                handler(true)
//            } catch {
//                let logMsg =  className + ":" + #function
//                sendLogMessage(error: error, defaultFname:logMsg)
//            }
//        }
    }
    
    /**
     # 설명
     서버와 소켓 통신을 연결한다.
     */
    func socketConnect(retryConnect: Bool = false) {
        self.retryConnect = retryConnect
        
        if !self.isConnected  {
            self.socket?.connect()
            resetTimer()
            
            Dprint("====================================== Socket connected : \(Date())")
        } else {
            Dprint("====================================== Socket is already connected : \(Date())")
        }
    }
    
    func stopTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    func resetTimer() {
        stopTimer()
//        isSuccessPing = false
        if pingTimer == nil {
            pingTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(sendPing), userInfo: nil, repeats: true)
        }
    }
    
    @objc func sendPing() {
        if isConnected == true {
            pingCount += 1
//            self.socket?.write(ping: Data())
            socket?.write(string: "")
            print("ping count: \(pingCount) : \(Date())")
            
            let debugDateFormatter: DateFormatter = DateFormatter()
            debugDateFormatter.dateFormat = "yy-MM-dd HH:mm:ss.SSS"
            
            let debugNowDate = debugDateFormatter.string(from: Date())
            debugPingCount += 1
            debugLastPingDate = debugNowDate
        }
//        if isConnected == false {
//            debugConnectFailCount += 1
//        }

//            guard reconnectAlert == nil else { return }
//            stopTimer()
//            reconnectAlert = UIAlertController(title: FinupString.guide.rawValue, message: "네트워크 오류입니다.\n재연결 하시겠습니까?", preferredStyle: .alert)
//            reconnectAlert!.addAction(UIAlertAction(title: FinupString.confirm.rawValue, style: .default, handler: { _ in
//                self.isSuccessPing = true
//                self.socketConnect()
//                self.reconnectAlert = nil
//            }))
//            reconnectAlert!.addAction(UIAlertAction(title: FinupString.cancel.rawValue, style: .destructive, handler: { _ in
//                self.reconnectAlert = nil
//                goToHomeTabVC()
//            }))
//            getTopViewController()?.present(reconnectAlert!, animated: true, completion: nil)
        
//        if( isSuccessPing == false ) {
//            stopTimer()
//        }
        redrawDebugPanel()
    }
    
    /**
     # 설명
     서버와 소켓 통신을 끊는다.
     */
    func socketDisconnect() {
        FSUtils.loadingChatStop()
        
        if self.isConnected {
            isConnected = false
//            isSuccessPing = true
            stopTimer()
            self.socket?.disconnect()
            Dprint("====================================== Socket disconnected : \(Date())")
        } else {
            Dprint("====================================== Socket is already disconnected : \(Date())")
        }
    }
    
    // MARK: - WebSocketDelegate
    /**
     # 설명
     서버로부터 정보가 내려오면 해당 정보에 따라 기능을 수행한다.
     
     - Parameters:
        - event: 서버에서 전송된 데이터 이벤트
        - client: 클라이언트 웹 소켓
     */
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        
        debugSocketStatus = "Connected"
        
        switch event {
        case .connected(let headers):
            isConnected = true
            delegate?.didConnected()
            FSUtils.loadingChatStop()
            Dprint("====================================== Socket is connected : \(Date()) : \(headers)")
            break
        case .disconnected(let reason, let code):
            Dprint("::::::::::::::::::::::::::::::::::::::: Socket is disconnected: \(reason) with code: \(code) : \(Date())")
            debugSocketStatus = "DisConnected | \(reason) | \(Date())"
            redrawDebugPanel()
            
            isConnected = false
            guard reason != "DUP_CON" else {
//                    socketDisconnect()
                Dprint("DUP_CON ::::::::::: SHOW ALERT")
                let alertVC = UIAlertController(title: FinupString.guide.rawValue, message: FinupString.api_Code_9102.rawValue, preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: FinupString.confirm.rawValue, style: .default, handler: { _ in
                    logout { (_, _) in
                        MemberStockPoint.shared.removeAll()
                        goToHomeTabVC()
                    }
                }))
                getTopViewController()?.present(alertVC, animated: true, completion: nil)
                return
            }
            
//            isSuccessPing = false
//            if retryConnect {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
//                    self.socketConnect(retryConnect: true)
//                    FSUtils.loadingChatStop()
//                })
//            }
            break
        case .text(let string):
            do {
//                isSuccessPing = true
                resetTimer()
                
                guard let dict = convertToDictionary(text: string) else {
                    throw FinupError.ApiDataParseError(className: className, funcName: #function)
                }
                guard let jsonObject = dict["JsonObject"] as? String else {
                    throw FinupError.ApiDataParseError(className: className, funcName: #function)
                }
                if (dict["Operaion"] as? String) == "OPERATION_HOST_SERVER_AVAILABLE" {
                    pongProcess()
                    return
                }
                guard let chatDict = convertToDictionary(text: jsonObject) else {
                    throw FinupError.ApiDataParseError(className: className, funcName: #function)
                }
                guard chatDict.isEmpty == false else {
                    throw FinupError.EmptyValueError(className: className, funcName: #function)
                }
                Dprint("Received text: \(chatDict)")
                let model = FinupChatMessageModel(dic: chatDict as NSDictionary)
                guard model.messageType != .system else {
                    MessageReceiveController.shared.systemMessage(model: model)
                    throw FinupError.SystemMessageError(className: className, funcName: #function)
                }
                model.userIdx = ""
                MessageReceiveController.shared.updateChatRoomList(messageModel: model)
                MessageReceiveController.shared.updateMessageList(messageModel: model)
                let status = MessageReceiveController.shared.getChatRoomAlarmStatus(messageModel: model)
                let title = MessageReceiveController.shared.getChatRoomTitle(messageModel: model)
                if let chatRoomIdx = MessageReceiveController.shared.fcChatRoomViewController?.chatRoomInfo?.chatIdx, chatRoomIdx != model.chatIdx && status == "1" {
                    FSUtils.showChatNotiMsg(nickname: model.nickName, msgTalk: model.messageTalk, roomTitle: title, chatIdx: model.chatIdx, isShowBanner: true)
                } else if let chatRoomIdx = MessageReceiveController.shared.goldenSignalViewController?.chatRoomInfo?.chatIdx, chatRoomIdx != model.chatIdx && status == "1" {
                    FSUtils.showChatNotiMsg(nickname: model.nickName, msgTalk: model.messageTalk, roomTitle: title, chatIdx: model.chatIdx, isShowBanner: true)
                }
                    
                if let chatVC = MessageReceiveController.shared.fcChatRoomViewController,
                   chatVC.chatRoomInfo?.chatIdx == model.chatIdx {
                    if chatVC.areaType == "3" && model.areaType == "2" {
                        chatVC.chatRoomInfo?.addBadgeMentor()
                    } else if chatVC.areaType == "2" && model.areaType == "3" {
                        chatVC.chatRoomInfo?.addBadgeUser()
                    }
                    
                    if chatVC.areaType == "2" {
                        let badge = chatVC.chatRoomInfo?.userBadgeCount ?? "0"
                        let badgeCount = badge.toInt() > 99 ? "99+   " : "\(badge)   "
                        if badge == "0" {
                            chatVC.userBadgeLabel.isHidden = true
                            chatVC.userAreaContentsPaddingConstraint.constant = 0
                        } else {
                            chatVC.userBadgeLabel.isHidden = false
                            chatVC.userAreaContentsPaddingConstraint.constant = 9
                            chatVC.userBadgeLabel.text = badgeCount
                        }
                        chatVC.mentorBadgeLabel.isHidden = true
                        chatVC.mentorAreaContentsPaddingConstraint.constant = 0
                    } else if chatVC.areaType == "3" {
                        let badge = chatVC.chatRoomInfo?.mentorBadgeCount ?? "0"
                        let badgeCount = badge.toInt() > 99 ? "99+   " : "\(badge)   "
                        if badge == "0" {
                            chatVC.mentorBadgeLabel.isHidden = true
                            chatVC.mentorAreaContentsPaddingConstraint.constant = 0
                        } else {
                            chatVC.mentorBadgeLabel.isHidden = false
                            chatVC.mentorAreaContentsPaddingConstraint.constant = 9
                            chatVC.mentorBadgeLabel.text = badgeCount
                        }
                        chatVC.userBadgeLabel.isHidden = true
                        chatVC.userAreaContentsPaddingConstraint.constant = 0
                    }
                }
                
            } catch { 
                let logMsg =  className + ":" + #function
                Dprint("====================================== Socket Error Log : \(Date())")
                Dprint(string)
                sendLogInfoMessage(param: string, defaultFname:logMsg)
            }
            break
        case .binary(let data):
            Dprint("Received data: \(data.count)")
            break
        case .ping(_):
            Dprint("====================================== Socket Ping : \(Date())")
            break
        case .pong(_):
            pongProcess()
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            Dprint("====================================== Socket ReconnectSuggested : \(Date())")
            debugSocketStatus = "ReconnectSuggested | \(Date())"
//            self.chatVC?.showToastMsg(sMsg: "신호가 등록되었습니다.")
            if MessageReceiveController.shared.fcChatRoomViewController != nil {
                FSUtils.loadingChatStart(vc: MessageReceiveController.shared.fcChatRoomViewController!, alpha: 0.0)
                MessageReceiveController.shared.fcChatRoomViewController?.showToastMsg(sMsg: "네트워크 변경이 감지되었습니다.")
            }
            else if MessageReceiveController.shared.chatListViewController != nil {
                FSUtils.loadingChatStart(vc: MessageReceiveController.shared.chatListViewController!, alpha: 0.0)
                MessageReceiveController.shared.chatListViewController?.showToastMsg(sMsg: "네트워크 변경이 감지되었습니다.")
            }
            
            isConnected = true
//            isSuccessPing = false
            retryConnect = true
            socketDisconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: {
                self.socketConnect(retryConnect: false)
                FSUtils.loadingChatStop()
            })
            break
        case .cancelled:
            Dprint("====================================== Socket Cancelled : \(Date())")
            debugSocketStatus = "Cancelled \(Date())"
            isConnected = true
//            isSuccessPing = false
            socketDisconnect()
//            if MessageReceiveController.shared.chatListViewController != nil {
//                Dprint("====================================== Socket retryConnect")
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
//                    self.socketConnect(retryConnect: false)
//                })
//            }
            break
        case .error(let error):
            Dprint("====================================== Socket Error : \(Date())")
            debugSocketStatus = "Socket Error \(Date())"
            isConnected = false
//            isSuccessPing = false
            stopTimer()
            handleError(error)
            break
        }
    }
    
    func pongProcess() {
        let debugDateFormatter: DateFormatter = DateFormatter()
        debugDateFormatter.dateFormat = "yy-MM-dd HH:mm:ss.SSS"
        
        let debugNowDate = debugDateFormatter.string(from: Date())
        
        debugPingFailCount += 1
        debugLastPingFailDate = debugNowDate
        
        print("pong count: \(debugPingFailCount) : \(Date())")
        Dprint("====================================== Socket Pong : \(Date())")
        
        redrawDebugPanel()
    }
    
    /**
     # 설명
     웹 소켓에서 내려온 애러를 출력하고 대응하는 함수
     
     - Parameters:
        - error: 에러
     */
    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            Dprint("websocket encountered an error: \(e.message)")
        } else if let e = error {
            Dprint("websocket encountered an error: \(e.localizedDescription)")
        } else {
            Dprint("websocket encountered an error")
        }
    }
}
