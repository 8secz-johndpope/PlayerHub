//
//  NormalViewController.swift
//  PlayerHubSample
//
//  Created by 廖雷 on 2019/10/12.
//  Copyright © 2019 Danis. All rights reserved.
//

import UIKit

class NormalViewController: UIViewController {
    
    let playerBox = NormalPlayerBox()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(playerBox)
        
        playerBox.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(playerBox.snp.width).multipliedBy(9.0 / 16.0)
        }
        let shortVideo = "http://flv3.bn.netease.com/tvmrepo/2018/6/9/R/EDJTRAD9R/SD/EDJTRAD9R-mobile.mp4"
        playerBox.replace(with: URL(string: shortVideo)!)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
