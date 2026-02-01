import Foundation
import Cocoa

class ImageStorageService {
    private let textEncryptionService = EncryptionService()
    
    private var imagesDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Pastelet/Images")
    }
    
    init() {
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        guard let url = imagesDirectory else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func saveImage(_ image: NSImage) -> UUID? {
        guard let tiffData = image.tiffRepresentation,
              let encryptedData = textEncryptionService.encrypt(tiffData),
              let dir = imagesDirectory else {
            return nil
        }
        
        let id = UUID()
        let fileURL = dir.appendingPathComponent("\(id.uuidString).enc")
        
        do {
            try encryptedData.write(to: fileURL)
            return id
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    func loadImage(id: UUID) -> NSImage? {
        guard let dir = imagesDirectory else { return nil }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).enc")
        
        guard let encryptedData = try? Data(contentsOf: fileURL),
              let decryptedData = textEncryptionService.decrypt(encryptedData) else {
            return nil
        }
        
        return NSImage(data: decryptedData)
    }
    
    func deleteImage(id: UUID) {
        guard let dir = imagesDirectory else { return }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).enc")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func deleteAllImages() {
        guard let dir = imagesDirectory else { return }
        try? FileManager.default.removeItem(at: dir)
        createDirectoryIfNeeded()
    }
}
