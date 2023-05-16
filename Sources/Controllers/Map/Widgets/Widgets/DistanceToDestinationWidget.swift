//
//  DistanceToDestinationWidget.swift
//  OsmAnd Maps
//
//  Created by Paul on 11.05.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

import Foundation
import CoreLocation

@objc(OADistanceToDestinationWidget)
@objcMembers
class DistanceToDestinationWidget: OADistanceToPointWidget {
    
    init() {
        super.init(icons: "widget_target_day", nightIconId: "widget_target_night")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func getPointToNavigate() -> CLLocation? {
        let p = OATargetPointsHelper.sharedInstance()!.getPointToNavigate()
        return p?.point
    }
    
    override func getDistance() -> CLLocationDistance {
        let routingHelper = OARoutingHelper.sharedInstance()!
        if routingHelper.isRouteCalculated() {
            return CLLocationDistance(routingHelper.getLeftDistance())
        }
        
        return super.getDistance()
    }
}
