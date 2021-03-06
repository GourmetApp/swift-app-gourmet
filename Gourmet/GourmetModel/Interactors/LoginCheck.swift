//
//  LoginCheck.swift
//  Gourmet
//
//  Created by David Martinez on 08/12/2016.
//  Copyright © 2016 Atenea. All rights reserved.
//

import Foundation

public protocol LoginCheckListener : NSObjectProtocol {
    
    func onSuccess (caller: LoginCheck, account : Account)
    func onError (caller: LoginCheck, error : LoginCheck.ErrorType)
    
}

public class LoginCheck : NSObject, LoginCheckParseListener, StoreAccountListener {
    
    public enum ErrorType : Error {
        case cardIdNotExists
        case passwordInvalid
        case connectionProblem
        case parseError
        case unknown
    }
    
    private var dm : GourmetServiceDM!
    private var parser : LoginCheckParser!
    private var storeAccount : StoreAccount!
    
    private weak var listener : LoginCheckListener?
    private var account : Account?
    
    public init(dm : GourmetServiceDM,
         parser : LoginCheckParser,
         storage : StoreAccount) {
        
        super.init()
        self.dm = dm
        self.parser = parser
        self.parser.setListener(listener: self)
        self.storeAccount = storage
        self.storeAccount.setListener(listener: self)
    }
    
    public func setListener (listener : LoginCheckListener?) {
        self.listener = listener
    }
    
    public func setAccount (account : Account) {
        self.account = account
    }
    
    public func execute () {
        guard listener != nil else {
            print("A listener must be set to LoginCheck interactor")
            return
        }
        
        guard account != nil else {
            print("An account must be set to LoginCheck interactor")
            return
        }
        
        dm.validate(account: account!) { (url: URL?, error: Error?) in
            if (url == nil) {
                DispatchQueue.main.async {
                    self.listener?.onError(caller: self, error: .connectionProblem)
                }
            } else {
                self.parser.execute(contentsOfFile: url!)
            }
        }
    }
    
    // MARK: LoginCheckParserListener
    public func onSuccess(parser: LoginCheckParser, response: ResponseLogin) {
        if (response.code == ResponseLogin.VALID_ID) {
            storeAccount.setAccount(account: account!)
            storeAccount.execute()
        } else if (response.code == ResponseLogin.INVALID_ID) {
            DispatchQueue.main.async {
                self.listener?.onError(caller: self, error: .cardIdNotExists)
            }
        } else if (response.code == ResponseLogin.INVALID_PASSWORD) {
            DispatchQueue.main.async {
                self.listener?.onError(caller: self, error: .passwordInvalid)
            }
        } else {
            DispatchQueue.main.async {
                self.listener?.onError(caller: self, error: .unknown)
            }
        }
    }
    
    public func onError(parser: LoginCheckParser) {
        DispatchQueue.main.async {
            self.listener?.onError(caller: self, error: .parseError)
        }
    }
    
    // MARK: StoreAccountListener
    public func onFinish(interactor: StoreAccount) {
        DispatchQueue.main.async {
            self.listener?.onSuccess(caller: self, account: self.account!)
        }
    }
}
