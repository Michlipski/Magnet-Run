//
//  GameScene.swift
//  Magnet Run
//
//  Created by Lipski, Michael on 2017-05-15.
//  Copyright © 2017 Lipski, Michael. All rights reserved.
//  This project encompasses the game "Magnet Run," a side scrolling vertical manipulation adventure through generated levels. The player must manipulate gravity fields that run along the floor of the levels to avoid said floor and continue forward toward the goal of the level.

import SpriteKit
import GameplayKit

class GameScene: SKScene,SKPhysicsContactDelegate {
    //this constant can be switched to true to disable dying, primarily for testing purposes
    let debugModeEnabled = false
    
    //the default swift delay function
    func delay(_ delay:Double, closure:@escaping ()->()) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
    
    //--//variable declaration//--//
    //the player's orb and camera are reserved so they can be accessed throughout the entire scene class
    var magnet:SKSpriteNode?
    var cameraNode:SKCameraNode = SKCameraNode()
    
    //the bitmask categories; these are used to distinguish types of node for collisions and contact notifications as well as which are affected by what fields
    let noCategory:UInt32 = 0
    let magnetCategory:UInt32 = 0b1 << 1
    let wallCategory:UInt32 = 0b1 << 2
    let goalCategory:UInt32 = 0b1 << 3
    let pushoffCategory:UInt32 = 0b1 << 4
    let goalGravityCategory:UInt32 = 0b1 << 5
    let pushoffGravityCategory:UInt32 = 0b1 << 6
    let ceilingCategory:UInt32 = 0b1 << 7
    
    //variables and constants used in determining difficulty, scaling, sizes etc.
    static var deathState = 2 //the way the character has transitioned from the game scene to the menu is stored with this variable
    var level = 0
    let numLayers = 4 //the number of vertical layers of the walls appearing above and below the orb
    let cameraDisplacement:CGFloat = -100
    let cameraScaleFactor:CGFloat = 2
    var levelLength = 5000
    let levelHeight = 20
    var numPushoffs = 10
    var activated = false //used to prevent exploitation of the pushoffs, this disallows repeated pressing of the pushoffs and changes from false to true when one is pressed, reverting after the pushoff is deactivated
    var wallType = "Edge5"
    let wallLength = 10 //the number of nodes long the walls on the top and bottom of the screen are
    var wallWidth:CGFloat?
    var wallHeight:CGFloat?
    var isBehind = 1 //used to store the current position of the 2 walls that chase the orb; describes which layer is behind the other so that it can be moved in front when the positions need to be updated
    
    //arrays for storing the walls, and pushoffs and their names
    var wallArrays = [[[SKSpriteNode]]]() //the horizontal portions of the walls acting as the floor and ceiling are stored in this three dimensional array
    var pushoffsArray = [SKSpriteNode]()
    var pushoffNamesArray = [String]()
    var pushoffFieldsArray = [SKFieldNode]()
    var wallArrays2 = [[SKSpriteNode]]() //the chasing walls are stored here
    
    //this function is called when the player transitions to this scene, and handles the initial setup of the level
    override func didMove(to view: SKView) {

        GameScene.deathState = 0 //the deathstate is reset to indicate the player has not failed
        level = MenuScene.level //the level is retrieved from the menu scene
        wallType = "Edge\(level%5+1)" //the wall texture is selected based on the level
        
        numPushoffs = Int(log2(Double(level+10))*5) //the number of pushoffs and the length of the level are determined based on the level. They will ideally increase rapidly over the first few levels and then level out
        levelLength = Int(log2(Double(level+2))*10000)
        
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = CGVector(dx: 0, dy: -0.5)
        self.backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.30, alpha: 1.0)
        
        //the player's orb is created
        magnet = SKSpriteNode(imageNamed: "pBall")
        magnet?.position = CGPoint(x: 0, y: 0)
        magnet?.setScale(2)
        magnet?.name = "magnet"
        magnet?.physicsBody = SKPhysicsBody(circleOfRadius: (magnet?.size.width)! / 2)
        magnet?.physicsBody?.categoryBitMask = magnetCategory
        magnet?.physicsBody?.contactTestBitMask = goalCategory | wallCategory //the orb will trigger a notification when it hits either the goal, or the floor
        magnet?.physicsBody?.collisionBitMask = wallCategory | ceilingCategory //the orb will physically interact with either the ceiling, chasing walls, or the floor
        magnet?.physicsBody?.fieldBitMask = goalGravityCategory | pushoffGravityCategory //the orb is affected by the pushoff gravity fields and by the end goal's gravity field
        magnet?.physicsBody?.affectedByGravity = true
        magnet?.physicsBody?.velocity = CGVector(dx: 300, dy: 0)
        magnet?.physicsBody?.allowsRotation = false
        magnet?.physicsBody?.linearDamping = 0.2
        self.addChild(magnet!)
        
        //the end goal is created, it is a larger version of player's own orb
        let goal = SKSpriteNode(imageNamed: "pBall")
        goal.position = CGPoint(x: levelLength, y: 0)
        goal.setScale(5)
        goal.name = "goal"
        goal.physicsBody = SKPhysicsBody(circleOfRadius: goal.size.width / 2)
        goal.physicsBody?.affectedByGravity = false
        goal.physicsBody?.allowsRotation = false
        goal.physicsBody?.pinned = true
        goal.physicsBody?.categoryBitMask = goalCategory //the goal does not interact with anything but the player's orb
        goal.physicsBody?.collisionBitMask = noCategory
        goal.physicsBody?.contactTestBitMask = magnetCategory
        goal.physicsBody?.fieldBitMask = noCategory
        self.addChild(goal)
        
        //the goal's gravity field is created
        let goalGravity = SKFieldNode.radialGravityField()
        goalGravity.physicsBody = SKPhysicsBody(circleOfRadius: goal.size.width / 20)
        goalGravity.physicsBody?.pinned = true
        goalGravity.physicsBody?.affectedByGravity = false
        goalGravity.physicsBody?.allowsRotation = false
        goalGravity.physicsBody?.categoryBitMask = goalGravityCategory
        goalGravity.strength = 5
        goal.addChild(goalGravity)
        
        //the camera is created, it has a set height and its horizontal position is set every frame to follow the orb
        self.camera = cameraNode
        cameraNode.position = magnet!.position
        cameraNode.position.y += cameraDisplacement
        cameraNode.setScale(cameraScaleFactor)
        self.addChild(cameraNode)
        
        //the functions to create the walls and pushoffs are called
        generateWalls()
        createPushoffs()
    }
    
    
    
    func touchDown(atPoint pos : CGPoint) {
    }
    
    func touchMoved(toPoint pos : CGPoint) {
    }
    
    func touchUp(atPoint pos : CGPoint) {
    }
    
    //this function is called when a contact notification between two nodes occurs
    func didBegin(_ contact: SKPhysicsContact) {
        let cA:UInt32 = contact.bodyA.categoryBitMask
        let cB:UInt32 = contact.bodyB.categoryBitMask
        //check which node is the orb, and call the collision function, passing it the other node
        if cA == magnetCategory || cB == magnetCategory {
            let otherNode:SKNode = (cA == magnetCategory) ? contact.bodyB.node! : contact.bodyA.node!
            magnetDidCollide(with: otherNode)
        }
    }
    
    //this function checks whether the player's node collided with the goal and succeeded, or hit the floor and failed
    func magnetDidCollide(with other: SKNode) {
        let otherCategory = other.physicsBody?.categoryBitMask
        //stop the orb from moving and transtion to the menu if they hit the goal
        if otherCategory == goalCategory {
            magnet?.physicsBody?.isDynamic = false
            transitionToMenu()
        }
        //stop the orb from moving and trigger the gameover function
        else if otherCategory == wallCategory && debugModeEnabled == false{
            magnet?.physicsBody?.isDynamic = false
            gameover()
        }
    }
    
    //when the player taps the screen, check if they've hit a pushoff, and trigger the activation function for that pushoff node if that is the case
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
        let touch = touches as! Set<UITouch>
        let location = touch.first!.location(in: self)
        let node = self.atPoint(location)
        if node.name != nil {
            if pushoffNamesArray.contains(node.name!) {
                let number = pushoffNamesArray.index(of: node.name!) //returns the position of the name in the names array, which corresponds to the position of the pushoff node in the pushoff node array
                activatePushoff(number!)
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
    
    //this function simply changes the deathstate to indicate the player failed, and continues to transition to the menu
    func gameover() {
        GameScene.deathState = 1
        transitionToMenu()
    }
    
    //this function handles the transition to the menu scene
    func transitionToMenu() {
        let menuScene = MenuScene(size: self.size)
        let transition = SKTransition.fade(with: SKColor(red: 0.15, green: 0.15, blue: 0.30, alpha: 1.0), duration: 0.5)
        menuScene.scaleMode = SKSceneScaleMode.aspectFill
        //create a manual fade node, that starts with a transparency, or alpha, value that starts at 0 and increases until it reaches 1 and the actual transition to the menu is started
        let fadeOut:SKSpriteNode = SKSpriteNode(color: UIColor.black, size: CGSize(width: self.size.width*cameraScaleFactor*5, height: self.size.height*cameraScaleFactor*5))
        fadeOut.zPosition = 2
        fadeOut.position = CGPoint(x: (cameraNode.frame.midX), y: (cameraNode.frame.midY))
        fadeOut.alpha = 0
        magnet?.addChild(fadeOut)
        for i in 0..<100 {
            delay(Double(i)*0.03) {
                fadeOut.alpha = CGFloat(0.01*Double(i))
            }
        }
        delay(3) {
            self.scene!.view?.presentScene(menuScene, transition: transition)
        }

    }
    
    //this function handles the creation of the pushoffs
    func createPushoffs() {
        for i in 0..<numPushoffs {
            let name = "pushoff\(i)" //the pushoffs are given unique names so that they can be distinguished when activated
            pushoffNamesArray.append(name)
            let pushoff = SKSpriteNode(imageNamed: "pushoff")
            pushoff.position = CGPoint(x: levelLength*i/numPushoffs, y: Int(wallArrays[1][0][0].position.y))
            pushoff.setScale(5)
            pushoff.zPosition = 0
            pushoff.name = name
            pushoff.alpha = 0.5
            pushoff.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pushoff.size.width, height: pushoff.size.height))
            pushoff.physicsBody?.categoryBitMask = pushoffCategory
            pushoff.physicsBody?.contactTestBitMask = magnetCategory
            pushoff.physicsBody?.collisionBitMask = noCategory
            pushoff.physicsBody?.fieldBitMask = noCategory
            pushoff.physicsBody?.affectedByGravity = false
            pushoff.physicsBody?.allowsRotation = false
            pushoff.physicsBody?.pinned = true
            //the pushoff's field is created and attached to the pushoff
            let pushoffField = SKFieldNode.radialGravityField()
            pushoffField.physicsBody = SKPhysicsBody(circleOfRadius: 1)
            pushoffField.physicsBody?.categoryBitMask = pushoffGravityCategory
            pushoffField.physicsBody?.allowsRotation = false
            pushoffField.physicsBody?.affectedByGravity = false
            pushoffField.physicsBody?.pinned = true
            pushoffField.strength = -0.001
            pushoffField.falloff = 0
            
            pushoff.addChild(pushoffField)
            self.addChild(pushoff)
            pushoffsArray.append(pushoff)
            pushoffFieldsArray.append(pushoffField)
            
        }
    }
    
    //this function handles the amplification of the gravity fields for the pushoffs when they are tapped
    func activatePushoff(_ valued: Int) {
        if activated == false { //check that there isn't already a pushoff activated
            activated = true
            for i in 0..<100 {//make the pushoff visually pulse by increasing and then decreasing its transparency
                delay(Double(i)*0.005) {
                    self.pushoffsArray[valued].alpha = CGFloat(0.005*Double(i)+0.5)
                }
                delay(Double(i)*0.005+0.5) {
                    self.pushoffsArray[valued].alpha = CGFloat(1-0.005*Double(i))
                }
            }
            //activate the gravity field by setting its strength to -1, and then revert it after 0.5 seconds
            pushoffFieldsArray[valued].strength = -1
            delay(0.5) {
                self.activated = false
                self.pushoffFieldsArray[valued].strength = -0.01
            }

        }
    }

    //this function handles the creation of the walls
    func generateWalls() {
        //store the dimensions of the walls for ease of use
        let wallDimensionGet = SKSpriteNode(imageNamed: wallType)
        wallDimensionGet.setScale(10)
        wallWidth = wallDimensionGet.size.width
        wallHeight = wallDimensionGet.size.height
        //add elements to the dimensions of the walls arrays
        for _ in 0..<2 {
            wallArrays.append([])
            wallArrays2.append([])
        }
        
        for p in 0..<2 {
            for _ in 0..<numLayers {
                wallArrays[p].append([])
            }
            
        }
        //create the floor and ceiling based on the number of nodes long and number of layers
        for i in 0..<wallLength {
            for n in 0..<numLayers {
                for p in 0..<2 {
                    let topBottom = (p*2) - 1 //determine whether this iteration is for the top or bottom layer
                    let wall = SKSpriteNode(imageNamed: wallType)
                    let xPos = i*Int(wallWidth!) - 500 - Int(wallWidth!/2)*(n%2)
                    let yPos = topBottom*(-Int(wallHeight!)*(levelHeight/2-numLayers)) - n*topBottom*Int(wallHeight!)
                    wall.position = CGPoint(x: xPos, y: yPos)
                    wall.setScale(10)
                    wall.zPosition = -2
                    wall.name = "wall\(p)"
                    wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallWidth!, height: wallHeight!))
                    if topBottom == 1 {
                        wall.physicsBody?.categoryBitMask = wallCategory
                    }
                    else {
                        wall.physicsBody?.categoryBitMask = ceilingCategory
                    }

                    wall.physicsBody?.collisionBitMask = magnetCategory
                    wall.physicsBody?.contactTestBitMask = magnetCategory
                    wall.physicsBody?.fieldBitMask = noCategory
                    wall.physicsBody?.allowsRotation = false
                    wall.physicsBody?.pinned = true
                    wall.physicsBody?.isDynamic = false
                    self.addChild(wall)
                    wallArrays[p][n].append(wall)
                }
            }
        }
        //create the chasing walls
        for i in 0..<levelHeight-1 {
            for n in 0..<2 {
                let wall = SKSpriteNode(imageNamed: wallType)
                let xPos = wallArrays[0][0][0].position.x - CGFloat(n)*wallWidth!
                let yPos = wallArrays[0][numLayers-1][0].position.y - CGFloat(i)*wallHeight!
                wall.position = CGPoint(x: xPos, y: yPos)
                wall.setScale(10)
                wall.zPosition = -3
                wall.name = "sideWall"
                wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallWidth!, height: wallHeight!))
                wall.physicsBody?.categoryBitMask = ceilingCategory
                wall.physicsBody?.collisionBitMask = magnetCategory
                wall.physicsBody?.contactTestBitMask = noCategory
                wall.physicsBody?.fieldBitMask = noCategory
                wall.physicsBody?.allowsRotation = false
                wall.physicsBody?.pinned = true
                wall.physicsBody?.isDynamic = false
                self.addChild(wall)
                wallArrays2[n].append(wall)
                
            }
        }

    }
    // Called before each frame is rendered
    override func update(_ currentTime: TimeInterval) {
        //check if the walls need to be moved forward, and update the position of the camera
        wallUpdate()
        cameraNode.position.x = magnet!.position.x
    }
    
    //this function updates the position of the walls
    func wallUpdate() {
        //check if the floor and ceiling are too far behind, and move the back nodes to the front if this is the case
        if (magnet?.position.x)! - wallArrays[0][0][0].position.x > 1200 {
            for p in 0..<wallArrays.count {
                for n in 0..<wallArrays[p].count {
                    wallArrays[p][n][0].position.x += CGFloat(wallLength-1)*wallWidth!
                    let tempWall = wallArrays[p][n][0]
                    self.removeChildren(in: [wallArrays[p][n][0]])
                    wallArrays[p][n].remove(at: 0)
                    self.addChild(tempWall)
                    wallArrays[p][n].append(tempWall)
                }
            }
            
            
        }
        //check if the back layer of the chasers is too far behind and move it in front if this is the case. Declare the other layer as the back layer if there is a move.
        if (magnet?.position.x)! - wallArrays2[isBehind][0].position.x > 1480 {
            for n in 0..<wallArrays2[isBehind].count {
                wallArrays2[isBehind][n].position.x = wallArrays2[isBehind][n].position.x + 2*wallWidth!
            }
            if isBehind == 1 {
                isBehind = 0
            }
            else {
                isBehind = 1
            }
        }
    }
    
}
