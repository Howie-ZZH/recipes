import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum ImageUtils {
    /// Compresses raw image Data to a lightweight JPEG Data (max dimension 800px, quality 0.6)
    public static func compressImageData(_ data: Data?, maxDimension: CGFloat = 800, quality: CGFloat = 0.6) -> Data? {
        guard let data = data, !data.isEmpty else { return nil }
        
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        
        var newSize = image.size
        if image.size.width > maxDimension || image.size.height > maxDimension {
            if image.size.width > image.size.height {
                newSize = CGSize(width: maxDimension, height: image.size.height * (maxDimension / image.size.width))
            } else {
                newSize = CGSize(width: image.size.width * (maxDimension / image.size.height), height: maxDimension)
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return (resizedImage ?? image).jpegData(compressionQuality: quality) ?? data
        #else
        return data
        #endif
    }
    
    /// Converts image data to compressed Base64 string for lightweight network transmission
    public static func compressImageToBase64(_ data: Data?, maxDimension: CGFloat = 800, quality: CGFloat = 0.6) -> String? {
        guard let compressed = compressImageData(data, maxDimension: maxDimension, quality: quality) else { return nil }
        return compressed.base64EncodedString()
    }
}
