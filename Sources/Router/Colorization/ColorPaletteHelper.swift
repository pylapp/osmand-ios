//
//  ColorPaletteHelper.swift
//  OsmAnd Maps
//
//  Created by Skalii on 02.07.2024.
//  Copyright © 2024 OsmAnd. All rights reserved.
//

import Foundation

@objcMembers
final class ColorPaletteHelper: NSObject {

    static let shared = ColorPaletteHelper()

    private var app: OsmAndAppProtocol
    private var cachedColorPalette = [String: ColorPalette]()

    private override init() {
        app = OsmAndApp.swiftInstance()
    }

    func getPalletsForType(_ gradientType: Int, isTerrainType: Bool) -> [String: [Any]] {
        if !isTerrainType {
            return getColorizationTypePallets(EOAColorizationType(rawValue: gradientType)!)
        } else {
            return getTerrainModePallets(TerrainMode.TerrainType(rawValue: Int32(gradientType))!)
        }
    }

    func requireGradientColorPaletteSync(_ colorizationType: EOAColorizationType, gradientPaletteName: String) -> ColorPalette {
        guard let colorPalette = getGradientColorPaletteSync(colorizationType, gradientPaletteName: gradientPaletteName), isValidPalette(colorPalette) else {
            return OARouteColorize.getDefaultPalette(colorizationType)
        }
        return colorPalette
    }

    func getGradientColorPaletteSync(_ colorizationType: EOAColorizationType, gradientPaletteName: String) -> ColorPalette? {
        getGradientColorPaletteSync(colorizationType, gradientPaletteName: gradientPaletteName, refresh: false)
    }

    func getGradientColorPaletteSync(_ colorizationType: EOAColorizationType, gradientPaletteName: String, refresh: Bool) -> ColorPalette? {
        getGradientColorPalette("route_\(getColorizationTypeName(colorizationType))_\(gradientPaletteName)\(TXT_EXT)", refresh: refresh)
    }

    func getGradientColorPaletteSyncWithModeKey(_ modeKey: String) -> ColorPalette? {
        getGradientColorPalette(modeKey)
    }

    func getGradientColorPalette(_ colorPaletteFileName: String) -> ColorPalette? {
        getGradientColorPalette(colorPaletteFileName, refresh: false)
    }

    func getGradientColorPalette(_ colorPaletteFileName: String, refresh: Bool) -> ColorPalette? {
        if let cachedPalette = cachedColorPalette[colorPaletteFileName], !refresh {
            return cachedPalette
        }
        let filePath = getColorPaletteDir().appendingPathComponent(colorPaletteFileName)
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let colorPalette = try ColorPalette.parseColorPalette(from: filePath)
                cachedColorPalette[colorPaletteFileName] = colorPalette
                return colorPalette
            } catch {
                debugPrint("Error reading color file: \(error)")
            }
        }
        return nil
    }

    private func getColorizationTypePallets(_ type: EOAColorizationType) -> [String: [Any]] {
        var colorPalettes: [String: [Any]] = [:]
        let colorTypePrefix = "route_\(getColorizationTypeName(type))_"
        
        do {
            let colorFiles = try FileManager.default.contentsOfDirectory(atPath: getColorPaletteDir())
            for fileName in colorFiles where fileName.hasPrefix(colorTypePrefix) && fileName.hasSuffix(TXT_EXT) {
                let colorPalleteName = fileName.replacingOccurrences(of: colorTypePrefix, with: "").replacingOccurrences(of: TXT_EXT, with: "")
                if let colorPalette = getGradientColorPalette(fileName) {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileName)
                    let modificationDate = fileAttributes[.modificationDate] as! Date
                    colorPalettes[colorPalleteName] = [colorPalette, modificationDate.timeIntervalSince1970]
                }
            }
        } catch {
            debugPrint("Error reading color palette directory: \(error)")
        }
        
        return colorPalettes
    }

    private func getTerrainModePallets(_ type: TerrainMode.TerrainType) -> [String: [Any]] {
        var colorPalettes: [String: [Any]] = [:]
        for mode in TerrainMode.values where mode.type == type {
            let fileName = mode.getMainFile()
            let filePath = getColorPaletteDir().appendingPathComponent(fileName)
            if let colorPalette = getGradientColorPalette(fileName), FileManager.default.fileExists(atPath: filePath) {
                let fileAttributes = try? FileManager.default.attributesOfItem(atPath: filePath)
                let modificationDate = fileAttributes?[.modificationDate] as? Date
                colorPalettes[mode.getKeyName()] = [colorPalette, modificationDate?.timeIntervalSince1970 ?? 0]
            }
        }
        return colorPalettes
    }

    private func isValidPalette(_ palette: ColorPalette?) -> Bool {
        guard let palette else {
            return false
        }
        return palette.colorValues.count >= 2
    }

    private func getColorPaletteDir() -> String {
        app.colorsPalettePath
    }

    private func getColorizationTypeName(_ type: EOAColorizationType) -> String {
        switch type {
        case .slope:
            return "slope"
        case .speed:
            return "speed"
        case .elevation:
            return "elevation"
        default:
            return "none"
        }
    }
}