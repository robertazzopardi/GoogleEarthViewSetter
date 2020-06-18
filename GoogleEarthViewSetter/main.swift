//
//  main.swift
//  GoogleEarthViewerSetter
//
//  Created by Robert Azzopardi-Yashi on 22/04/2020.
//  Copyright © 2020 BisonCo. All rights reserved.
//

import AppKit

extension String {
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }
    
    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            try pngData?.write(to: url, options: options)
            return true
        } catch {
            return false
        }
    }
}

class Main { 
    //"https://www.gstatic.com/prettyearth/assets/full/[HERE].jpg"
    let homeDirectory: URL
    let thisFolder: URL
    let logPath: URL
    let fileManager: FileManager
    var sequence: [Int]!
    let lowerBound = 1000, upperBound = 14794
    
    init() {
        self.fileManager = FileManager.default
        
        self.homeDirectory = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
        
        self.thisFolder = homeDirectory.appendingPathComponent("GoogleEarthViewer")
        
        self.logPath = thisFolder.appendingPathComponent("EarthViewLog.txt")
        
        if !fileManager.fileExists(atPath: thisFolder.path) {
            do {
                try fileManager.createDirectory(atPath: thisFolder.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
            }
        }
        
        if !fileManager.fileExists(atPath: logPath.path) {
            fileManager.createFile(atPath: logPath.path, contents: "".data(using: .utf8))
        }   
        
        self.sequence = generateRandomUniqueNumbers3(forLowerBound: lowerBound, andUpperBound: upperBound, andNumNumbers: upperBound-lowerBound)
    }
    
    fileprivate func randomNumber(between lower: Int, and upper: Int) -> Int {
        return Int(arc4random_uniform(UInt32(upper - lower))) + lower
    }
    
    fileprivate func generateRandomUniqueNumbers3(forLowerBound lower: Int, andUpperBound upper:Int, andNumNumbers iterations: Int) -> [Int] {
        /// create a unique sequence from the bounds 
        guard iterations <= (upper - lower) else { return [] }
        var numbers: Set<Int> = Set<Int>()
        (0..<iterations).forEach { _ in
            let beforeCount = numbers.count
            repeat {
                numbers.insert(randomNumber(between: lower, and: upper))
            } while numbers.count == beforeCount
        }
        return numbers.map{ $0 }
    }
    
    fileprivate func writeLog(_ file: String) {
        let text = try! String(contentsOf: logPath, encoding: String.Encoding.utf8)
        let lines = text.components(separatedBy: CharacterSet.newlines)
        
        /// if the file is not already in the log then append it
        if !lines.contains(file) {
            do {
                try "\(file)".appendLineToURL(fileURL: logPath)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    fileprivate func getFileInfo(_ f1: String, _ folder: URL) -> (URL, Date, String)? {
        let fileURL1 = folder.appendingPathComponent(f1)
        let attributes = try! fileManager.attributesOfItem(atPath: fileURL1.path)
        let date = attributes[FileAttributeKey.creationDate] as! Date
        
        /// if the file is not an image (may have hidden files etc) return nothing for the file information
        if fileURL1.pathExtension == "jpg" {
            return (fileURL1, date, fileURL1.pathExtension)
        } else {
            return nil
        }
    }
    
    fileprivate func oldestFile(_ f1: (URL, Date, String), _ f2: (URL, Date, String)) -> Bool {
        /// return true if file 2 is older than file 1
        return f1.1 < f2.1
    }
    
    fileprivate func saveFile(_ data: Data?, _ wallpaper: URL) {
        do {
            /// gets the file information of the files in the projects folder and store in a list
            let fileNames = try fileManager.contentsOfDirectory(atPath: thisFolder.path)
            let fileInfo = fileNames.compactMap { getFileInfo($0, thisFolder)}.sorted(by: oldestFile(_:_:))
            
            /// if there are more than 10 images in the folder delete the oldest until there is 10 
            if fileInfo.count >= 10 {
                for i in 0...fileInfo.count-10 {
                    try fileManager.removeItem(at: fileInfo[i].0)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        
        /// save the image
        if let imageData = data {
            let image = NSImage(data: imageData)
            _ = image!.pngWrite(to: wallpaper, options: .withoutOverwriting)
        }
    }
    
    fileprivate func setWallpaper(_ wallpaper: URL) {
        /// set the background for every screen available
        for screen in NSScreen.screens {
            do {
                try NSWorkspace().setDesktopImageURL(wallpaper, for: screen, options: [:])
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    fileprivate func setBackground(_ number: Int) {
        /// choose a random number from the squence
        let r = sequence[number]
        /// add to the path where the picture should be saved
        let wallpaper = thisFolder.appendingPathComponent("\(r).jpg")
        let url = URL(string: "https://www.gstatic.com/prettyearth/assets/full/\(r).jpg")!
        
        /// make a connection to the url, does not have a list of available files so have to check if there is a file associated
        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
            
            /// check the response from the url and get the data if it does
            guard let data = data, let httpResponse = response as? HTTPURLResponse, error == nil else {
                print("No valid response")
                return
            }
            
            /// check the response code is valid else call setBackground to try another url
            guard 200 ..< 299 ~= httpResponse.statusCode else {
                self.setBackground(number+1)
                return
            }
            
            self.saveFile(data, wallpaper)
            
            self.setWallpaper(wallpaper)
            
            self.writeLog(url.absoluteString)
            
            /// exit when done
            exit(EXIT_SUCCESS)
        })
        task.resume()
        
        /// needed to run background tasks 
        RunLoop.main.run()
    }
}

let start = Main()
start.setBackground(0)
