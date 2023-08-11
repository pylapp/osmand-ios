//
//  TravelHelper.swift
//  OsmAnd Maps
//
//  Created by nnngrach on 11.08.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

import Foundation


protocol GpxReadCallback {
    func onGpxFileReading()
    func onGpxFileRead(gpxFile: String?)
}


protocol TravelHelper {
    func getBookmarksHelper() -> TravelLocalDataHelper
    func initializeDataOnAppStartup()
    func initializeDataToDisplay(resetData: Bool)
    func isAnyTravelBookPresent() -> Bool
    func search(searchQuery: String) -> [WikivoyageSearchResult]
    func getPopularArticles() -> [TravelArticle]
    func getNavigationMap(article: TravelArticle) -> [WikivoyageSearchResult : [WikivoyageSearchResult]]
    func getArticleById(articleId: TravelArticleIdentifier, lang: String?, readGpx: Bool, callback: GpxReadCallback?) -> TravelArticle?
    func findSavedArticle(savedArticle: TravelArticle) -> TravelArticle?
    func getArticleByTitle(title: String, lang: String, readGpx: Bool, callback: GpxReadCallback?) -> TravelArticle?
    func getArticleByTitle(title: String, latLon:CLLocationCoordinate2D, lang: String, readGpx: Bool, callback: GpxReadCallback?) -> TravelArticle?
    func getArticleByTitle(title: String, rect: QuadRect, lang: String, readGpx: Bool, callback: GpxReadCallback?) -> TravelArticle?
    func getArticleId(title: String, lang: String) -> TravelArticleIdentifier?
    func getArticleLangs(articleId: TravelArticleIdentifier) -> [String]
    func searchGpx(latLon:CLLocationCoordinate2D, fileName: String?, ref: String?) -> TravelGpx?
    func openTrackMenu(article: TravelArticle, gpxFileName: String, latLon:CLLocationCoordinate2D)
    func getGPXName(article: TravelArticle) -> String
    func createGpxFile(article: TravelArticle) -> String
    
    // TODO: this method should be deleted once TravelDBHelper is deleted
    //String getSelectedTravelBookName();
    //String getWikivoyageFileName();
    
    func saveOrRemoveArticle(article: TravelArticle, save: Bool)
}
