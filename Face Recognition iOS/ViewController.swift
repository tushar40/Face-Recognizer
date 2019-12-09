//
//  ViewController.swift
//  Face Recognition iOS
//
//  Created by Tushar Gusain on 03/12/19.
//  Copyright © 2019 Hot Cocoa Software. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    //MARK:- Outlets
    @IBOutlet var nameTextField: UITextField! {
        didSet {
            nameTextField.delegate = self
        }
    }
    
    @IBOutlet var selectedPhoto: UIImageView! {
        didSet {
            selectedPhoto.isUserInteractionEnabled = true
        }
    }
    
    @IBOutlet var searchingLabel: UILabel!
    
    //MARK:- Member Variables
    private var selectedPerson: Person?
    private var isLoading: Bool = true
    private var isIdentifying = false {
        didSet {
            if !isIdentifying {
                DispatchQueue.main.async {
                    self.searchingLabel.isHidden = true
                }
            }
        }
    }
    private var result = [Result]()
    let groupID = ApplicationConstants.personGroupId
    let groupName = "DemoGroup"
    let groupData = "This is a sample group"
    
    private var imagePickerVC: UIImagePickerController {
        let vc = UIImagePickerController()
        vc.delegate = self
        vc.allowsEditing = true
        vc.sourceType = .camera
        return vc
    }
    
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    let dataOutputQueue = DispatchQueue(
        label: "video data queue",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    var faceView = FaceView()
    let nameLayer = CATextLayer()
    
    var faceViewHidden = false
    
    var maxX: CGFloat = 0.0
    var midY: CGFloat = 0.0
    var maxY: CGFloat = 0.0
    var boxArray: [CGRect] = []
    let defaultName = "Guest"
    
    var nameTag = "Guest" {
        didSet {
            nameLayer.string = nameTag
            if nameTag == defaultName {
                if (searchingLabel.text?.contains("Confidence"))! {
                    searchingLabel.text = "Searching for a match..."
                    searchingLabel.isHidden = true
                }
                nameLayer.foregroundColor = .init(srgbRed: 0, green: 0, blue: 1, alpha: 1)
            } else {
                nameLayer.foregroundColor = .init(srgbRed: 0, green: 255, blue: 0, alpha: 1)
            }
        }
    }
    
    
    var sequenceHandler = VNSequenceRequestHandler()
    
    //MARK:- UIImagePickerDelegate method
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[.editedImage] as? UIImage else {
            print("no image found")
            return
        }
        print(image)
        selectedPhoto.image = image
        selectedPerson = Person(name: "")
        if let name = nameTextField.text {
            selectedPerson!.name = name
        }
        selectedPerson!.image = image
    }
    
    //MARK:- UITextFieldDelegate method
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    //MARK:- UIViewController methods
    override func viewDidLoad() {
        super.viewDidLoad()
//                createPersonGroup(groupId: groupID)
        //        selectedPhoto.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ShowImagePicker)))
        getPersonListInCollection(personGroupId: groupID)

        configureCaptureSession()

        searchingLabel.isHidden = true
        nameLayer.alignmentMode = .center
        nameLayer.fontSize = 22

        faceView.frame = selectedPhoto.bounds
        faceView.isOpaque = false
        selectedPhoto.addSubview(faceView)

        maxX = view.bounds.maxX
        midY = view.bounds.midY
        maxY = view.bounds.maxY

        session.startRunning()
        
    }
    
    //MARK:- IBAction methods
    @IBAction func recognizePerson(_ sender: UIButton) {
        identifyFace()
    }
    
    @IBAction func addPersonToCollection(_ sender: UIButton) {
        selectedPerson = Person(name: "")
        selectedPerson?.name = nameTextField.text!
        selectedPerson?.image = selectedPhoto.image
        if selectedPerson?.name != "" {
            addPerson(name: selectedPerson!.name, userData: nil, personGroupId: groupID)
        } else {
            alert(title: "Unable add", message: "Add a name to the person")
        }
    }
    
    @IBAction func getStoredPersons(_ sender: UIButton) {
        getPersonListInCollection(personGroupId: groupID)
    }
    
    //MARK:- Member functions
    
    // In order for detection to work,
    // We need to:
    //  1. create personGroup   :
    //  2. add a person to personGroup
    //  3. upload person's face(s)
    //  4. train
    //  5. check train completion
    //  5. detect faces in a photo
    //  6. identify
    
    @objc func ShowImagePicker() {
        imagePickerVC.sourceType = .camera
        present(imagePickerVC, animated: true)
    }
    
    func identifyFace()
    {
        self.searchingLabel.isHidden = false
        isIdentifying = true
        
        self.checkForTrainComplete(personGroupId: groupID, completion: {
            DispatchQueue.main.async {
                self.detectFaces(photo: self.selectedPhoto.image!, completion: { (faces) in
                    self.identifyFaces(faces: faces, personGroupId: self.groupID/*, personToFind: personIDDictionary[self.selectedPerson!.name]!*/)
                })
            }
        })
    }
    
    func createPersonGroup(groupId: String) {
        FaceAPI.createPersonGroup(personGroupId: groupID,
                                  name: groupName,
                                  userData: groupData) { (result) in
                                    switch result {
                                    case .Success(let json):
                                        print("Created person group - ", json)
                                        self.alert(title: "Successfully created group", message: "to group - \(groupId)")
                                    case .Failure(let error):
                                        print("Error creating person group - ", error)
                                        self.alert(title: "Error", message: "Error creating person group")
                                    }
        }
    }
    
    func addPerson(name: String, userData: String?, personGroupId: String)
    {
        FaceAPI.createPerson(personName: name, userData: userData, personGroupId: personGroupId) { (result) in
            switch result {
            case .Success(let json):
                let personId = json["personId"] as! String
                print("Created person - ", personId)
                personIDDictionary[name] = personId
                self.uploadPersonFace(image: self.selectedPerson!.image!, personId: personId, personGroupId: personGroupId)
                break
            case .Failure(let error):
                print("Error adding a person - ", error)
                self.alert(title: "Error", message: "Error adding a person")
                self.isLoading = false
                break
            }
        }
    }
    
    
    func uploadPersonFace(image: UIImage, personId: String, personGroupId: String)
    {
        FaceAPI.uploadFace(faceImage: image, personId: personId, personGroupId: personGroupId) { (result) in
            switch result {
            case .Success(_):
                print("face uploaded - ", personId)
                self.getPersonListInCollection(personGroupId: self.groupID)
                self.train(personGroupId: personGroupId/*, personToFind: personId*/)
                break
            case .Failure(let error):
                print("Error uploading a face - ", error)
                self.alert(title: "Error", message: "Error uploading a face")
                self.isLoading = false
                break
            }
        }
    }
    
    func train(personGroupId: String/*, personToFind: String*/)
    {
        FaceAPI.trainPersonGroup(personGroupId: personGroupId) { (result) in
            switch result {
            case .Success(_):
                print("train posted")
                //                 self.checkForTrainComplete(personGroupId: personGroupId, completion: {
                //                    self.detectFaces(photo: self.selectedPhoto.image!, completion: { (faces) in
                //                         self.identifyFaces(faces: faces, personGroupId: personGroupId, personToFind: personToFind)
                //                     })
                //                 })
                break
            case .Failure(let error):
                print("Error posting to train - ", error)
                self.alert(title: "Error", message: "Error posting to train")
                self.isLoading = false
                break
            }
        }
    }
    
    
    func checkForTrainComplete(personGroupId: String, completion: @escaping () -> Void) {
        FaceAPI.getTrainingStatus(personGroupId: personGroupId) { (result) in
            switch result {
            case .Success(let json):
                print("training complete - ", json)
                let status = json["status"] as! String
                
                if status == "notstarted" || status == "running" {
                    print("Training in progress")
                    
                    let delayTime = DispatchTime.now() + .seconds(1)
                    DispatchQueue.main.asyncAfter(deadline: delayTime) {
                        self.checkForTrainComplete(personGroupId: personGroupId, completion: completion)
                    }
                }
                else if status == "failed" {
                    print("Training failed -", json)
                    self.alert(title: "Error", message: "Training failed")
                    self.isIdentifying = false
                }
                else if status == "succeeded" {
                    print("Training succeeded")
                    completion()
                }
                
                break
            case .Failure(let error):
                print("Training incomplete or error - ", error)
                self.alert(title: "Error", message: "Training incomplete or error")
                self.isLoading = false
                self.isIdentifying = false
                break
            }
        }
    }
    
    func detectFaces(photo: UIImage, completion: @escaping (_ faces: [Face]) -> Void)
    {
        print("Detecting the face from image")
        FaceAPI.detectFaces(facesPhoto: photo) { (result) in
            switch result {
            case .Success(let json):
                var faces = [Face]()
                
                let detectedFaces = json as! JSONArray
                for item in detectedFaces {
                    let face = item as! JSONDictionary
                    let faceId = face["faceId"] as! String
                    let rectangle = face["faceRectangle"] as! [String: AnyObject]
                    
                    let detectedFace = Face(faceId: faceId,
                                            height: rectangle["top"] as! Int,
                                            width: rectangle["width"] as! Int,
                                            top: rectangle["top"] as! Int,
                                            left: rectangle["left"] as! Int)
                    faces.append(detectedFace)
                }
                completion(faces)
                print("Got the detected face")
                break
            case .Failure(let error):
                print("DetectFaces error - ", error)
                self.alert(title: "Error", message: "Error detecting the face")
                self.isLoading = false
                self.isIdentifying = false
                break
            }
        }
    }
    
    func identifyFaces(faces: [Face], personGroupId: String/*, personToFind: String*/) {
        
        print("Looking for the detected face...")
        print("in group", personGroupId)
        var faceIds = [String]()
        for face in faces {
            faceIds.append(face.faceId)
        }
        
        FaceAPI.identify(faces: faceIds, personGroupId: personGroupId) { (result) in
            switch result {
            case .Success(let json):
                let jsonArray = json as! JSONArray
                self.result = [Result]()
                
                for item in jsonArray {
                    let face = item as! JSONDictionary
                    let faceId = face["faceId"] as! String
                    let candidates = face["candidates"] as! JSONArray
                    
                    var personFound = ""
                    for candidate in candidates {
                        //                         if candidate["personId"] as! String == personToFind {
                        //                             // find face information based on faceId
                        DispatchQueue.main.async {
                            personFound = candidate["personId"] as! String
                            for face in faces {
                                if face.faceId == faceId {
                                    let faceImage = self.cropFace(face: face, image: self.selectedPhoto.image!)
                                    let confidence = candidate["confidence"]!!
                                    self.searchingLabel.text = "Confidence:- \(confidence.doubleValue)"
                                    //
                                    //                                    var outputString = "confidence: \(confidence)\n"
                                    //                                    outputString += "dimensions: \n";
                                    //                                    outputString += "   top   : \(Int(face.top))\n"
                                    //                                    outputString += "   left  : \(Int(face.left))\n"
                                    //                                    outputString += "   width : \(Int(face.width))\n"
                                    //                                    outputString += "   height: \(Int(face.height))\n"
                                    
                                    let detectedFace = Result(image: faceImage, otherInformation: ""/*outputString*/)
                                    self.result.append(detectedFace)
                                }
                            }
                            print("Result array of matching persons",result)
                        }
                        
                        //                         }
                    }
                    self.isLoading = false
                    DispatchQueue.main.async {
                        if self.result.count == 0 {
                            self.alert(title: "No match Found!!", message: "Number of matching persons: \(self.result.count)")
                        } else {
                            let personName = personIDDictionary[personFound]!
//                            self.alert(title: "Hello \(personName).", message: "Number of matching persons: \(self.result.count)")
                            self.nameTag = personName
                        }
                        self.isIdentifying = false
                    }
                }
            case .Failure(let error):
                print("Identifying faces error - ", error)
                self.alert(title: "Error", message: "error identifying face")
                self.isLoading = false
                self.isIdentifying = false
                break
            }
        }
    }
    
    func getPersonListInCollection(personGroupId: String) {
        FaceAPI.getPersonListInGroup(personGroupId: personGroupId) { (result) in
            switch result {
            case .Success(let json):
                print("Got the list of persons - ", json)
                let jsonArray = json as! JSONArray
                
                for person in jsonArray {
                    print(person)
                    let personInfo = person as! JSONDictionary
                    let personId = personInfo["personId"] as! String
                    let name = personInfo["name"] as! String
                    personIDDictionary[personId] = name
                    //                    do {
                    //                        let personInfo = try JSONDecoder().decode(PersonResponse.self, from: person.data)
                    //                        let faceId = person["faceId"] as! String
                    //                        let name = person["name"] as! String
                    //                    } catch {
                    //                        print(error.localizedDescription)
                    //                    }
                }
                print(personIDDictionary)
                self.alert(title: "Person Count", message: "Number of person ids: \(personIDDictionary.count)")
                break
            case .Failure(let error):
                print("Error getting list of persons - ", error)
                self.alert(title: "Error", message: "Error getting list of persons")
                self.isLoading = false
                break
            }
        }
    }
    
    
    func cropFace(face: Face, image: UIImage) -> UIImage
    {
        let croppedSection = CGRect(x: CGFloat(face.left), y: CGFloat(face.top), width: CGFloat(face.width), height: CGFloat(face.height))
        let imageRef = image.cgImage!.cropping(to: croppedSection)
        
        let croppedImage = UIImage(cgImage: imageRef!)
        
        return croppedImage
    }
    
}

// MARK: - Video Processing methods
extension ViewController {
    func configureCaptureSession() {
        // Define the capture device we want to use
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
                                                    fatalError("No front video camera available")
        }
        
        // Connect the camera to the capture session input
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            session.addInput(cameraInput)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        // Create the video data output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // Add the video output to the capture session
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        
        // Configure the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = selectedPhoto.bounds
        previewLayer.bounds = selectedPhoto.frame
        
        view.layer.insertSublayer(previewLayer, at: 0)
        selectedPhoto.layer.insertSublayer(previewLayer, at: 0)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func landmark(point: CGPoint, to rect: CGRect) -> CGPoint {
        
        let absolute = point.absolutePoint(in: rect)
        
        let converted = previewLayer.layerPointConverted(fromCaptureDevicePoint: absolute)
        
        return converted
    }
    
    func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
        return points?.compactMap { landmark(point: $0, to: rect) }
    }
    
    func detectedFaces(request: VNRequest, error: Error?) {
        guard
            let results = request.results as? [VNFaceObservation],
            let result = results.first
            else {
                faceView.clear()
                nameTag = defaultName
                nameLayer.removeFromSuperlayer()
                return
        }
        
        updateFaceView(for: result)
    }
    
    func updateFaceView(for result: VNFaceObservation) {
        defer {
            DispatchQueue.main.async {
                self.faceView.setNeedsDisplay()
            }
        }
        
        let box = result.boundingBox
        faceView.boundingBox = previewLayer.layerRectConverted(fromMetadataOutputRect: box)
        
        guard let landmarks = result.landmarks else {
          return
        }
          
        if let leftEye = landmark(
          points: landmarks.leftEye?.normalizedPoints,
          to: result.boundingBox) {
          faceView.leftEye = leftEye
        }
        
        if let rightEye = landmark(
          points: landmarks.rightEye?.normalizedPoints,
          to: result.boundingBox) {
          faceView.rightEye = rightEye
        }
            
        if let leftEyebrow = landmark(
          points: landmarks.leftEyebrow?.normalizedPoints,
          to: result.boundingBox) {
          faceView.leftEyebrow = leftEyebrow
        }
            
        if let rightEyebrow = landmark(
          points: landmarks.rightEyebrow?.normalizedPoints,
          to: result.boundingBox) {
          faceView.rightEyebrow = rightEyebrow
        }
            
        if let nose = landmark(
          points: landmarks.nose?.normalizedPoints,
          to: result.boundingBox) {
          faceView.nose = nose
        }
            
        if let outerLips = landmark(
          points: landmarks.outerLips?.normalizedPoints,
          to: result.boundingBox) {
          faceView.outerLips = outerLips
        }
            
        if let innerLips = landmark(
          points: landmarks.innerLips?.normalizedPoints,
          to: result.boundingBox) {
          faceView.innerLips = innerLips
        }
            
        if let faceContour = landmark(
          points: landmarks.faceContour?.normalizedPoints,
          to: result.boundingBox) {
          faceView.faceContour = faceContour
        }
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else {
                return
            }
            
            self.nameLayer.frame = self.faceView.boundingBox
            self.faceView.layer.addSublayer(self.nameLayer)
        }
        
        boxArray.append(box)
        if boxArray.count == 15 {
            let displacement = getDistance(rect1: boxArray.first!, rect2: boxArray.last!)
            print("Box array full, distance: \(displacement)")
            boxArray = [CGRect]()
            if displacement.magnitude > 0.10 && !isIdentifying && nameTag == defaultName {
                print("Identifying face.")
                identifyFace()
            }
        }
    }
    
    func getDistance(rect1: CGRect, rect2: CGRect) -> CGFloat {
        let x2 = pow((rect1.origin.x - rect2.origin.x), 2)
        let y2 = pow((rect1.origin.y - rect2.origin.y), 2)
        return pow((x2 + y2), 0.5)
    }
    
    func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
        let image = self.convert(cmage: ciimage)
        DispatchQueue.main.sync {
            selectedPhoto.image = image.resized(toWidth: 144.0)//.resized(withPercentage: 0.8)
            let detectedFaceRequest = VNDetectFaceLandmarksRequest(completionHandler: detectedFaces)
            do {
                try sequenceHandler.perform([detectedFaceRequest], on: imageBuffer, orientation: .leftMirrored)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
}
