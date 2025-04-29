//
//  TrackPlayApp.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 07/03/2024.
//

import SwiftUI
import SUCo
import MetalDevice
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        MTDevice.shared.setup(){
            
        }
        FontLoader.loadAllFonts()
//       var model: MainViewController = MainViewController()
         SUCoordinator.setup(statusBarIsHidden: true)
         window = UIWindow(frame: UIScreen.main.bounds)
         window?.rootViewController = SUCoordinator.navigation
         window?.makeKeyAndVisible()
         SUCoordinator.moveToSUIView(from: .fromBottom, type: .fade, AnyView( ContentView() ))
        
        return true
    }
    func applicationWillTerminate(_ application: UIApplication) {
        
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        
    }
    

    func applicationDidEnterBackground(_ application: UIApplication) {
        
    }
  
}

