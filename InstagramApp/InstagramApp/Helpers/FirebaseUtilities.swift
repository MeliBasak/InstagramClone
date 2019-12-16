//
//  FirebaseUtilities.swift
//  InstagramApp
//
//  Created by Melih on 5.12.2019.
//  Copyright © 2019 BasakMelih. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore

protocol FirebaseUtilitiesDelegate {
    func presentAlert(title: String, message: String)
    func dismissPage()
    func loginSuccess()
    func postDataFetched(postList: [Post])
    func userDataFetched(userList: [User])
    
}

extension FirebaseUtilitiesDelegate {
    func presentAlert(title: String, message: String) {
    }
    func dismissPage() {
    }
    func loginSuccess() {
    }
    func postDataFetched(postList: [Post]) {
    }
    func userDataFetched(userList: [User]) {
    }
}

class FirebaseUtilities {
    var delegate: FirebaseUtilitiesDelegate?
    let storage = Storage.storage()
    var storageRef: StorageReference
    var postDict = [String : Any]()
    var userDict = [String : Any]()
    var userArray = [User]()
    var postArray = [Post]()
    
    init() {
        storageRef = storage.reference(forURL: "gs://instagramclone-b86bf.appspot.com")
    }
    
    func userForgotPassword(email: String?) {
        if let email = email{
            Auth.auth().sendPasswordReset(withEmail: email) { (error) in
                if let error = error {
                    self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                    return
                }else {
                    self.delegate?.presentAlert(title: "A reset password link has been sent to you!", message: "Please check your emails.")
                }
            }
        }
    }
    
    func login(email: String?, password: String?) {
        if let email = email {
            if let password = password {
                Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
                    if let error = error {
                        self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                    } else {
                        print("You are sign in.")
                        self.delegate?.loginSuccess()
                    }
                }
            }
        }
    }
    
    func signUp(email: String?, password: String?, data: Data?, username: String){
        if let email = email {
            if let password = password {
                Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
                    if let error = error {
                        self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                    } else {
                        if let user = user {
                            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                            changeRequest?.displayName = username
                            changeRequest?.commitChanges(completion: nil)
                            let imageRef = self.storageRef.child("profileImages").child("\(user.user.uid).jpg")
                            if let imageData = data {
                                let uploadTask = imageRef.putData(imageData, metadata: nil) { (metaData, error) in
                                    if let error = error {
                                        self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                                        return
                                    }
                                    imageRef.downloadURL { (url, error) in
                                        if let error = error {
                                            self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                                            return
                                        }
                                        if let url = url {
                                            let userInfo: [String: Any] = ["uid": user.user.uid,
                                                                           "userName": username,
                                                                           "urlToImage": url.absoluteString]
                                            let dataRef = Firestore.firestore().collection("users").document(user.user.uid).setData(userInfo) { (error) in
                                                if let error = error {
                                                    self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                                                    return
                                                }
                                                UserDefaults.standard.set(user.user.uid, forKey: "uid")
                                                self.delegate?.dismissPage()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func postImage (description: String, data: Data?) {
        let uid = Auth.auth().currentUser!.uid
        let dataRef = Firestore.firestore().collection("posts")
        let timeStamp = NSDate.timeIntervalSinceReferenceDate
        let imageRef = storageRef.child("posts").child(uid).child("\(timeStamp).jpg")
        if let imageData = data {
            let uploadTask = imageRef.putData(data!, metadata: nil) { (metaData, error) in
                if let error = error {
                    self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                imageRef.downloadURL { (url, error) in
                    if let error = error {
                        self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                        return
                    }
                    if let url = url {
                        let postInfo: [String: Any] = ["description": description,
                                                       "urlToPostImage": url.absoluteString,
                                                       "username": Auth.auth().currentUser?.displayName!,
                                                       "postId": String(timeStamp)]
                        dataRef.document(uid).collection("postObjects").document(String(timeStamp)).setData(postInfo) { (error) in
                            if let error = error {
                                self.delegate?.presentAlert(title: "Error", message: error.localizedDescription)
                                return
                            }
                            print("I have posted wohoo")
                            self.delegate?.dismissPage()
                        }
                    }
                }
            }
        }
    }
    
    func fetchUsers() {
        let dataRef = Firestore.firestore()
        dataRef.collection("users").getDocuments() {(querySnapshot, err) in
            if let err = err {
                self.delegate?.presentAlert(title: "Error", message: err.localizedDescription)
                return
            } else {
                for document in querySnapshot!.documents {
                    let userData = document.data()
                    var userObject = User()
                    self.userDict.updateValue(document.data(), forKey: document.documentID)
                    if let username = userData["userName"] as? String, let urlToImage = userData["urlToImage"] as? String, let uid = userData["uid"] as? String {
                        userObject.imageRef = urlToImage
                        userObject.uid = uid
                        userObject.userName = username
                        self.userArray.append(userObject)
                    }
                    self.fetchPosts(uid: document.documentID)
                }
            }
            
            self.delegate?.userDataFetched(userList: self.userArray)
        }
    }
    
    func fetchPosts(uid: String) {
        let dataRef = Firestore.firestore()
        dataRef.collection("posts").document(uid).collection("postObjects").getDocuments() {(querySnapshot, err) in
            if let err = err {
                self.delegate?.presentAlert(title: "Error", message: err.localizedDescription)
                return
            } else {
                for post in querySnapshot!.documents {
                    let postData = post.data()
                    var postObject = Post()
                    self.postDict.updateValue(postData, forKey: "\(uid)-\(post.documentID)")
                    if let description = postData["description"] as? String, let urlToPostImage = postData["urlToPostImage"] as? String, let username = postData["username"] as? String, let postId = postData["postId"] as? String {
                        postObject.description = description
                        postObject.postId = postId
                        postObject.urlToPostImage = urlToPostImage
                        postObject.username = username
                        self.postArray.append(postObject)
                    }                                    
                }
            }
            self.delegate?.postDataFetched(postList: self.postArray)
        }
    }
}
