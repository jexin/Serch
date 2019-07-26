//
//  ViewController.swift
//  Serch
//
//  Created by Jenny Xin on 7/8/19.
//  Copyright © 2019 Jenny Xin. All rights reserved.
//

import UIKit
import Firebase

extension UIImage {
    func crop(_ path: UIBezierPath) -> UIImage {
        UIGraphicsBeginImageContext(self.size)
        
        let context = UIGraphicsGetCurrentContext()!
        context.addPath(path.cgPath)
        context.clip()
        draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        UIGraphicsEndImageContext()
        
        return maskedImage
    }
}

class CircleView : UIView {
    var outGoingLine : CAShapeLayer?
    var inComingLine : CAShapeLayer?
    var inComingCircle : CircleView?
    var outGoingCircle : CircleView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = self.frame.size.width / 2
        self.backgroundColor = .red
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func lineTo(circle: CircleView) -> CAShapeLayer {
        let path = UIBezierPath()
        path.move(to: self.center)
        path.addLine(to: circle.center)
        
        let line = CAShapeLayer()
        line.path = path.cgPath
        line.lineWidth = 1
        line.strokeColor = UIColor.red.cgColor
        circle.inComingLine = line
        outGoingLine = line
        outGoingCircle = circle
        circle.inComingCircle = self
        return line
    }
    
    func redrawLine(circle: CircleView, line: CAShapeLayer, path: CGPath) {
        let newPath = UIBezierPath(cgPath: path)
        newPath.removeAllPoints()
        newPath.move(to: self.center)
        newPath.addLine(to: circle.center)
        line.path = newPath.cgPath
    }
}

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var photos: UIButton!
    @IBOutlet weak var capture: UIButton!
    @IBOutlet weak var camera: UIButton!
    @IBOutlet weak var display: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    
    // corners of scan area
    var one = CircleView(frame: CGRect(x: 15, y: 150, width: 15, height: 15))
    var two = CircleView(frame: CGRect(x: 325, y: 150, width: 15, height: 15))
    var three = CircleView(frame: CGRect(x: 15, y: 200, width: 15, height: 15))
    var four = CircleView(frame: CGRect(x: 325, y: 200, width: 15, height: 15))
    
    var viewWidth: CGFloat = 375 // initial width of imageView
    var viewHeight: CGFloat = 480 // initial height of imageView
    var viewCenter = CGPoint(x: 187.5, y: 390.5) // center image
    
    let imagePicker = UIImagePickerController() // control displayed image
    let uiImage = UIImage(named: "dummy") // dummy image
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        viewWidth = imageView.frame.width
        viewHeight = imageView.frame.height
        viewCenter = imageView.center
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        
        // image area
        imageView.image = refactorImage(sourceImage: uiImage!)
        imageView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(draggedView(_:))))
        run(sourceImage: imageView.image!)
        
        // scan area
        two.center.x = imageView.frame.width - 15
        four.center.x = imageView.frame.width - 15
        
        one.center.y = imageView.frame.height / 5
        two.center.y = imageView.frame.height / 5
        three.center.y = one.center.y + 50
        four.center.y = two.center.y + 50
        
        imageView.addSubview(one)
        imageView.addSubview(two)
        imageView.addSubview(three)
        imageView.addSubview(four)
        
        imageView.layer.addSublayer(one.lineTo(circle: two))
        imageView.layer.addSublayer(two.lineTo(circle: four))
        imageView.layer.addSublayer(four.lineTo(circle: three))
        imageView.layer.addSublayer(three.lineTo(circle: one))
        
        one.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:))))
        two.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:))))
        three.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:))))
        four.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:))))
        
        display.delegate = self
        imagePicker.delegate = self
        
    }
    
    // text recognition
    func run(sourceImage:UIImage) {
        let vision = Vision.vision()
        let textRecognizer = vision.onDeviceTextRecognizer()
        
        let croppedImage = cropImage(sourceImage, topLeft: one, topRight: two, bottomLeft: three,  bottomRight: four)
        let image = VisionImage(image: croppedImage!)
        textRecognizer.process(image) { result, error in
            guard error == nil, let result = result else {
                // alert if error
                self.display.text = ""
                return
            }
            // update text
            self.display.text = result.text
        }
    }
    
    // crop image from scanner view
    func cropImage(_ inputImage: UIImage, topLeft: UIView, topRight: UIView, bottomLeft: UIView, bottomRight: UIView) -> UIImage?
    {
        // adjust imageview
        let viewScale = min(viewWidth / imageView.image!.size.width,
                            viewHeight / imageView.image!.size.height)
        let imageWidth = viewScale * imageView.image!.size.width
        let imageHeight = viewScale * imageView.image!.size.height
        
        imageView.frame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight);
        imageView.center = viewCenter;
        
        // adjust points to scale
        let scale = max(inputImage.size.width / imageView.frame.size.width,
                        inputImage.size.height / imageView.frame.size.height)
        
        let newTopLeft = CGPoint(x: topLeft.center.x * scale, y:  topLeft.center.y * scale)
        let newTopRight = CGPoint(x: topRight.center.x * scale, y: topRight.center.y * scale)
        let newBottomLeft = CGPoint(x: bottomLeft.center.x * scale, y: bottomLeft.center.y * scale)
        let newBottomRight = CGPoint(x: bottomRight.center.x * scale, y: bottomRight.center.y * scale)
        
        let testPath = UIBezierPath()
        testPath.move(to: newTopLeft)
        testPath.addLine(to: newTopRight)
        testPath.addLine(to: newBottomRight)
        testPath.addLine(to: newBottomLeft)
        testPath.close()
        
        return inputImage.crop(testPath)
    }
    
    // fix orientation
    func refactorImage (sourceImage:UIImage) -> UIImage {
        let newWidth = sourceImage.size.width
        let newHeight = sourceImage.size.height
        
        UIGraphicsBeginImageContext(CGSize(width:newWidth, height:newHeight))
        sourceImage.draw(in: CGRect(x:0, y:0, width:newWidth, height:newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    // update image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            // replace image
            imageView.image = refactorImage(sourceImage: pickedImage)
            
            // detect text from image
            run(sourceImage: imageView.image!)
        }
        dismiss(animated: true)
    }
    
    // trigger camera
    @IBAction func launchCam(_ sender: UIButton) {
        if UIImagePickerController.availableCaptureModes(for: .rear) != nil {
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .camera
            imagePicker.cameraCaptureMode = .photo
            imagePicker.modalPresentationStyle = .fullScreen
            present(imagePicker, animated: true)
        } else {
            let alert = UIAlertController(title: "ERROR", message: "No camera available!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    // trigger photo selection
    @IBAction func selectPhoto(_ sender: UIButton) {
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true)
    }

    // trigger search button redirection
    @IBAction func search(_ sender: UIButton) {
        let input = self.display.text
        // when input is a valid url
        if (URL(string: "\(input!)") != nil) && input!.contains(".") {
            var link = URL(string: "\(input!)")!
            // add http/https if needed
            if !input!.hasPrefix("https://") && !input!.hasPrefix("http://") {
                link = URL(string: "http://\(input!)")!
            }
            // redirect to search
            if UIApplication.shared.canOpenURL(link as URL) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(link as URL, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(link as URL)
                }
            }
            // when input is a Google search
        } else if let query = input?.replacingOccurrences(of: " ", with: "+") {
            let webURL = URL(string: "http://www.google.com/search?q=\(query)")!
            // redirect to search
            if UIApplication.shared.canOpenURL(webURL as URL) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(webURL as URL, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(webURL as URL)
                }
            }
        } else {
            let alert = UIAlertController(title: "ERROR", message: "Oops. Something went wrong", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    // exit keyboard on return
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        search(capture)
        return true
    }
    
    // drag points
    @objc func didPan(gesture: UIPanGestureRecognizer) {
        guard let circle = gesture.view as? CircleView else {
            return
        }
        
        if (gesture.state == .began) {
            circle.center = gesture.location(in: imageView)
        }
        
        let newCenter: CGPoint = gesture.location(in: imageView)
        
        var dX = newCenter.x - circle.center.x
        var dY = newCenter.y - circle.center.y
        
        // add limits to dragging area
        dX = max(dX, -one.center.x)
        if (circle == one) {
            dX = min(dX, four.frame.maxX - one.center.x)
        }
        
        if (circle == two) {
            dX = max(dX, three.frame.maxX - two.center.x)
        }
        dX = min(dX, imageView.frame.width - two.center.x)
        
        dX = max(dX, -three.center.x)
        if (circle == three) {
            dX = min(dX, two.frame.minX - three.center.x)
        }
        
        if (circle == four) {
            dX = max(dX, one.frame.minX - four.center.x)
        }
        dX = min(dX, imageView.frame.width - four.center.x)
        
        dY = max(dY, -one.center.y)
        if (circle == one) {
            dY = min(dY, three.frame.minY - one.center.y)
        }
        
        dY = max(dY, -two.center.y)
        if (circle == two) {
            dY = min(dY, three.frame.minY - two.center.y)
        }
        
        if (circle == three) {
            dY = max(dY, one.frame.maxY - three.center.y)
        }
        dY = min(dY, imageView.frame.height - three.center.y)
        
        if (circle == four) {
            dY = max(dY, one.frame.maxY - four.center.y)
        }
        dY = min(dY, imageView.frame.height - four.center.y)
        
        circle.center = CGPoint(x: circle.center.x + dX, y: circle.center.y + dY)
        
        // redraw lines
        if let outGoingCircle = circle.outGoingCircle, let line = circle.outGoingLine, let path = circle.outGoingLine?.path {
            
            circle.redrawLine(circle: outGoingCircle, line: line, path: path)
        }
        
        if let inComingCircle = circle.inComingCircle, let line = circle.inComingLine, let path = circle.inComingLine?.path {
            
            inComingCircle.redrawLine(circle: circle, line: line, path: path)
        }
        
        if (gesture.state == .ended) {
            run(sourceImage: imageView.image!)
        }
    }
    
    // drag scanner area
    @objc func draggedView(_ sender:UIPanGestureRecognizer){
        var translation = sender.translation(in: self.view)
        
        // add limits to dragging area
        translation.x = max(translation.x, -one.frame.minX) // left top
        translation.x = max(translation.x, -three.frame.minX) // left bottom
        translation.x = min(translation.x, imageView.frame.width - two.frame.maxX) // right top
        translation.x = min(translation.x, imageView.frame.width - four.frame.maxX) // right bottom
        
        translation.y = max(translation.y, -one.frame.minY) // top left
        translation.y = max(translation.y, -two.frame.minY) // top right
        translation.y = min(translation.y, imageView.frame.height - three.frame.maxY) // bottom left
        translation.y = min(translation.y, imageView.frame.height - four.frame.maxY) // bottom right
        
        // translate points
        one.center = CGPoint(x: one.center.x + translation.x, y: one.center.y + translation.y)
        two.center = CGPoint(x: two.center.x + translation.x, y: two.center.y + translation.y)
        three.center = CGPoint(x: three.center.x + translation.x, y: three.center.y + translation.y)
        four.center = CGPoint(x: four.center.x + translation.x, y: four.center.y + translation.y)
        
        // translate lines
        one.redrawLine(circle: one.outGoingCircle!, line: one.outGoingLine!, path: one.outGoingLine!.path!)
        two.redrawLine(circle: two.outGoingCircle!, line: two.outGoingLine!, path: two.outGoingLine!.path!)
        three.redrawLine(circle: three.outGoingCircle!, line: three.outGoingLine!, path: three.outGoingLine!.path!)
        four.redrawLine(circle: four.outGoingCircle!, line: four.outGoingLine!, path: four.outGoingLine!.path!)
        
        sender.setTranslation(CGPoint.zero, in: self.view)
        
        if (sender.state == UIGestureRecognizer.State.ended) {
            run(sourceImage: imageView.image!)
        }
    }
}
