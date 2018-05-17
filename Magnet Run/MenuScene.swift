//
//  GameScene.swift
//  Magnet Run
//
//  Created by Lipski, Michael on 2017-05-15.
//  Copyright © 2017 Lipski, Michael. All rights reserved.
//

import SpriteKit
import GameplayKit

class MenuScene: SKScene,SKPhysicsContactDelegate {
    
    //variable declaration
    var ball: SKSpriteNode?
    var tapHere:SKSpriteNode?
    var stars: SKEmitterNode?
    var magnet:SKSpriteNode = SKSpriteNode(imageNamed: "pBall")
    static var level = 0 //the global level tracker for the game stages
    static var firstTime = true //keeps track of whether this is the first time the player has seen the menu
    var isFirstTime = false
    var tutorialStage = 0
    var tutorial:SKLabelNode?
    var tutorial2:SKLabelNode?
    var tutorial3:SKLabelNode?
    var pushoffExample:SKSpriteNode = SKSpriteNode(imageNamed: "pushoff")
    
    
    //the default swift delay function
    func delay(_ delay:Double, closure:@escaping ()->()) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
    
    //this function is called when the scene is presented, and handles much of the initial work
    override func didMove(to view: SKView) {
        
        //check whether the scene was transitioned to because of a death or a successful run and react accordingly
        if GameScene.deathState == 1 { //if the player failed and the level is not the first, revert to the previous level
            GameScene.deathState = 2
            if MenuScene.level > 0 {
                MenuScene.level += -1
            }
        }
        else if GameScene.deathState == 0 { //if the player succeeded, continue to the next level
            GameScene.deathState = 2
            MenuScene.level += 1
        }
        
        self.physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.30, alpha: 1.0)
        
        //a manual version of the fade transition that allows for the program to still run while it fades out; creates a large black sprite and increases the transparency until it reaches 1 and the transition occurs
        let fadeOut:SKSpriteNode = SKSpriteNode(color: UIColor.black, size: self.size)
        fadeOut.zPosition = 2
        fadeOut.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        fadeOut.alpha = 1
        self.addChild(fadeOut)
        for i in 0..<100 {
            delay(Double(i)*0.01) {
                fadeOut.alpha = CGFloat(1-0.01*Double(i))
            }
        }
        delay(1) {
            self.removeChildren(in: [fadeOut])
        }
        
        //add the purple orb, or magnet, that the player will control in the next scene
        magnet.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        magnet.setScale(2)
        magnet.zPosition = 1
        magnet.name = "magnet"
        self.addChild(magnet)
        
        //add particles that fly across the screen to simulate the visual of an object moving through space
        stars = SKEmitterNode(fileNamed: "stars")!
        stars?.position = CGPoint(x: self.frame.maxX, y: self.frame.midY)
        self.addChild(stars!)
        
        //check if this is the player's first time launching this scene and run the text tutorial if that is the case
        if MenuScene.firstTime == true {
            //because multi-lined label nodes aren't supported in this version, 3 seperate nodes must be made
            tutorial = SKLabelNode(fontNamed: "Papyrus")
            tutorial!.fontSize = 20
            tutorial!.position = CGPoint(x: 0, y: 150)
            tutorial!.text = "In this game, you will manipulate your object across"
            tutorial!.zPosition = 3
            tutorial!.name = "tutorial"
            self.addChild(tutorial!)
            
            tutorial2 = SKLabelNode(fontNamed: "Papyrus")
            tutorial2!.fontSize = 20
            tutorial2!.position = CGPoint(x: 0, y: 125)
            tutorial2!.text = "the floor to the goal orb. Try to beat as many levels"
            tutorial2!.zPosition = 3
            tutorial2!.name = "tutorial"
            self.addChild(tutorial2!)
            
            tutorial3 = SKLabelNode(fontNamed: "Papyrus")
            tutorial3!.fontSize = 20
            tutorial3!.position = CGPoint(x: 0, y: 100)
            tutorial3!.text = "as you can! Tap here to continue."
            tutorial3!.zPosition = 3
            tutorial3!.name = "tutorial"
            self.addChild(tutorial3!)
        }
        //create the level counter so the player can keep track of their progress
        let levelCounter = SKLabelNode(fontNamed: "Papyrus")
        levelCounter.fontSize = 40
        levelCounter.zPosition = 5
        levelCounter.name = "level"
        levelCounter.text = "\(MenuScene.level)"
        magnet.addChild(levelCounter)
        levelCounter.position = CGPoint(x: 150, y: 65)
                
    }
    
    //a function designed to simulate a node flashing, uses the delay function with parameters based on an input time to decrease and then increase the transparency. This function calls itself at the end to repeat indefinately.
    func fadeInOut(_ node: SKNode, _ time: Double) {
         if MenuScene.firstTime == true || isFirstTime == true{
            delay(time) {
                self.fadeInOut(node, time)
            }
            for i in 0..<50 {
                delay(time/100*Double(i)+time/2) {
                    node.alpha = CGFloat(i)*0.02
                }
                delay(time/100*Double(i)) {
                    node.alpha = 1-(CGFloat(i)*0.02)
                }

            }
        }
    }
    
    func touchDown(atPoint pos : CGPoint) {
    }
    
    func touchMoved(toPoint pos : CGPoint) {
    }
    
    func touchUp(atPoint pos : CGPoint) {
    }
    
    //called when the user taps the screen, this checks if they have hit purple orb after the tutorial and proceeds to the game if this is the case. Also checks if they have hit the tutorial text to indicate the desire to advance with the tutorial.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
        let touch = touches as! Set<UITouch>
        let location = touch.first!.location(in: self)
        let node = self.atPoint(location)
        
        if (node.name == "magnet") && MenuScene.firstTime == false{
            //remove the tutorial text if the orb is touched
            if isFirstTime == true {
                tutorial!.removeFromParent()
                tutorial2!.removeFromParent()
                tutorial3!.removeFromParent()
            }
            isFirstTime = false
            //begin the transition to the game scene, and accelerate the star particles so it looks like the orb is speeding up. The manual fade transition is also called at this time.
            let gameScene = GameScene(size: self.size)
            let transition = SKTransition.fade(with: SKColor(red: 0.15, green: 0.15, blue: 0.30, alpha: 1.0), duration: 0.5)
            gameScene.scaleMode = SKSceneScaleMode.aspectFill
            stars?.xAcceleration = -1000
            let fadeOut:SKSpriteNode = SKSpriteNode(color: UIColor.black, size: self.size)
            fadeOut.zPosition = 2
            fadeOut.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
            fadeOut.alpha = 0
            self.addChild(fadeOut)
            for i in 0..<100 {
                delay(Double(i)*0.03) {
                    fadeOut.alpha = CGFloat(0.01*Double(i))
                }
            }
            delay(3) {
                self.scene!.view?.presentScene(gameScene, transition: transition)
            }
            
        }
        //if the tutorial text is advanced, the next text is presented, and anything else that goes along with that stage of the tutorial
        else if (node.name == "tutorial") {
            tutorialStage += 1
            //in this stage an example of the "pushoffs" used in the game is presented and the fadeInOut function is called to draw the player's attention.
            if tutorialStage == 1 {
                pushoffExample.position = CGPoint(x: 80, y: 0)
                pushoffExample.alpha = 0.5
                pushoffExample.setScale(2)
                fadeInOut(pushoffExample, 2)
                magnet.addChild(pushoffExample)
                tutorial!.text = "To keep above the floor, tap on the"
                tutorial2!.text = "\"pushoffs\" like this one to get"
                tutorial3!.text = "propelled in the other direction. Tap here to continue."
            }
            //in this stage the pushoff example is removed and the next set of text is displayed
             else if tutorialStage == 2 {
                pushoffExample.removeFromParent()
                tutorial!.text = "Forward momentum can be quickly accumulated if"
                tutorial2!.text = "you aren't careful, so manipulate the pushoffs to"
                tutorial3!.text = "get into a stable rhythm. Tap here to continue."
            }
            //as this is the last stage, a flashing notification is shown over the orb to prompt the player to tap there, and the final set of text is displayed
            else if tutorialStage == 3 {
                MenuScene.firstTime = false
                isFirstTime = true
                tapHere = SKSpriteNode(imageNamed: "taphere")
                tapHere?.setScale(0.2)
                tapHere?.name = "magnet"
                magnet.addChild(tapHere!)
                tapHere?.position.x = -2
                tapHere?.zPosition = 5
                fadeInOut(tapHere!, 1)
                
                tutorial!.text = "That's all there is to it! Just be careful not"
                tutorial2!.text = "to touch the floor and have fun. Now"
                tutorial3!.text = "press the purple orb to start."
            }
        }

    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        
        
    }
}
