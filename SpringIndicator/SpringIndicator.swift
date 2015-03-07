//
//  SpringIndicator.swift
//  SpringIndicator
//
//  Created by Kyohei Ito on 2015/03/06.
//  Copyright (c) 2015年 kyohei_ito. All rights reserved.
//

import UIKit

@IBDesignable
public class SpringIndicator: UIView {
    public class Refresher: UIControl {
        private let ObserverOffsetKeyPath = "contentOffset"
        private let ScaleAnimationKey = "scaleAnimation"
        private let DefaultContentHeight: CGFloat = 60
        
        private var initialInsetTop: CGFloat = 0
        public private(set) var indicator = SpringIndicator(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        public private(set) var refreshing: Bool = false
        public var targetView: UIScrollView?
        public var refreshingInsetTop: CGFloat {
            return initialInsetTop + (refreshing ? bounds.height : 0)
        }
        
        public convenience init(targetView: UIScrollView) {
            self.init(frame: CGRect.zeroRect)
            
            self.targetView = targetView
        }
        
        override init(var frame: CGRect) {
            super.init(frame: frame)
            
            setupIndicator()
        }
        
        public required init(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            
            setupIndicator()
        }
        
        public override func drawRect(rect: CGRect) {
            super.drawRect(rect)
            
            targetView?.addObserver(self, forKeyPath: ObserverOffsetKeyPath, options: .New, context: nil)
        }
        
        public override func layoutSubviews() {
            super.layoutSubviews()
            
            if let superview = superview {
                frame.size.height = DefaultContentHeight
                frame.size.width = superview.bounds.width
                center.x = superview.center.x
                
                backgroundColor = UIColor.clearColor()
                userInteractionEnabled = false
                autoresizingMask = .FlexibleWidth | .FlexibleBottomMargin
            }
            
            if let targetView = targetView {
                initialInsetTop = targetView.contentInset.top
            }
        }
        
        public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
            if let scrollView = object as? UIScrollView {
                if scrollView.superview?.superview == nil {
                    scrollView.removeObserver(self, forKeyPath: ObserverOffsetKeyPath, context: nil)
                    targetView = nil
                    
                    return
                }
                
                var offsetY = initialInsetTop + scrollView.contentOffset.y
                frame.origin.y = offsetY
                
                if indicator.isSpinning() {
                    return
                }
                
                if refreshing && scrollView.dragging == false {
                    refreshStart(scrollView, sendActions: true)
                    
                    return
                }
                
                offsetY += frame.size.height - indicator.frame.size.height
                if offsetY > 0 {
                    offsetY = 0
                }
                
                let ratio = abs(offsetY / bounds.height)
                if ratio >= 1 {
                    refreshing = true
                } else {
                    refreshing = false
                }
                
                indicator.strokeRatio(ratio)
            }
        }
    }
    
    private let LotateAnimationKey = "rotateAnimation"
    private let ExpandAnimationKey = "expandAnimation"
    private let ContractAnimationKey = "contractAnimation"
    private let GroupAnimationKey = "groupAnimation"
    
    private let strokeTiming = [0, 0.3, 0.5, 0.7, 1]
    private let strokeValues = [0, 0.1, 0.5, 0.9, 1]
    
    private var starting: Bool = false
    private var rotateThreshold = (M_PI / M_PI_2 * 2) - 1
    private var indicatorView: UIView
    private var animationCount: Double = 0
    private var pathLayer: CAShapeLayer? {
        willSet {
            self.pathLayer?.removeFromSuperlayer()
        }
    }
    
    @IBInspectable public var animating: Bool = false
    @IBInspectable public var lineWidth: CGFloat = 3
    @IBInspectable public var lineColor: UIColor = UIColor.grayColor()
    @IBInspectable public var lotateDuration: Double = 1.5
    @IBInspectable public var strokeDuration: Double = 0.7
    
    public var intervalAnimationsHandler: ((SpringIndicator) -> Void)?
    private var stopAnimationsHandler: ((SpringIndicator) -> Void)?
    
    public override init(frame: CGRect) {
        indicatorView = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        super.init(frame: frame)
        indicatorView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        addSubview(indicatorView)
        
        backgroundColor = UIColor.clearColor()
    }
    
    public required init(coder aDecoder: NSCoder) {
        indicatorView = UIView()
        super.init(coder: aDecoder)
        indicatorView.frame = bounds
        indicatorView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        addSubview(indicatorView)
    }
    
    public override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        
        if animating {
            startAnimation()
        }
    }
    
    private func incrementAnimationCount() -> Double {
        animationCount++
        
        if animationCount > rotateThreshold {
            animationCount = 0
        }
        
        return animationCount
    }
    
    private func rotateLayer(count: Double) -> CAShapeLayer {
        animationCount = count
        
        let start = CGFloat(M_PI_2 * (0 - count))
        let end = CGFloat(M_PI_2 * (rotateThreshold - count))
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = max(bounds.width, bounds.height) / 2
        
        var arc = UIBezierPath(arcCenter: center, radius: radius,  startAngle: start, endAngle: end, clockwise: true)
        arc.lineWidth = 0
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = arc.CGPath
        shapeLayer.strokeColor = lineColor.CGColor
        shapeLayer.fillColor = nil
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = kCALineCapRound
        
        return shapeLayer
    }
}

public extension SpringIndicator.Refresher {
    public func startRefreshing(sendActions: Bool = false) {
        refreshing = true
        
        if let scrollView = targetView {
            refreshStart(scrollView, sendActions: sendActions)
        }
    }
    
    public func endRefreshing() {
        refreshing = false
        
        if let scrollView = targetView {
            if scrollView.contentInset.top > refreshingInsetTop {
                UIView.performSystemAnimation(.Delete, onViews: [], options: nil, animations: {
                    scrollView.contentInset.top = self.refreshingInsetTop
                    }, completion: nil)
            }
        }
        
        indicator.stopAnimation(true)
    }
}

private extension SpringIndicator.Refresher {
    private func setupIndicator() {
        indicator.lineWidth = 2
        indicator.lotateDuration = 1
        indicator.strokeDuration = 0.5
        indicator.center = center
        indicator.autoresizingMask = .FlexibleLeftMargin | .FlexibleRightMargin | .FlexibleTopMargin | .FlexibleBottomMargin
        addSubview(indicator)
    }
    
    private func refreshStart(scrollView: UIScrollView, sendActions: Bool) {
        scrollView.contentInset.top = refreshingInsetTop
        
        if sendActions {
            sendActionsForControlEvents(.ValueChanged)
        }
        
        indicator.layer.addAnimation(refreshAnimation(), forKey: ScaleAnimationKey)
        indicator.startAnimation(expand: true)
        
        scrollView.contentOffset.y -= scrollView.contentInset.top - initialInsetTop
        frame.origin.y = initialInsetTop + scrollView.contentOffset.y - bounds.height
    }
    
    private func refreshAnimation() -> CAPropertyAnimation {
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.duration = 0.1
        anim.repeatCount = 1
        anim.autoreverses = true
        anim.fromValue = 1
        anim.toValue = 1.3
        anim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        
        return anim
    }
}

public extension SpringIndicator {
    public func startAnimation(expand: Bool = false) {
        stopAnimationsHandler = nil
        
        if starting {
            return
        }
        
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.duration = lotateDuration
        anim.repeatCount = HUGE
        anim.fromValue = 0
        anim.toValue = M_PI * 2
        indicatorView.layer.addAnimation(anim, forKey: LotateAnimationKey)
        starting = true
        
        nextAnimation(expand)
    }
    
    public func stopAnimation(waitAnimation: Bool, completion: ((SpringIndicator) -> Void)? = nil) {
        if waitAnimation {
            stopAnimationsHandler = { indicator in
                indicator.stopAnimation(false, completion: completion)
            }
        } else {
            stopAnimationsHandler = nil
            indicatorView.layer.removeAnimationForKey(LotateAnimationKey)
            starting = false
            pathLayer = nil
            
            completion?(self)
        }
    }
    
    public func isSpinning() -> Bool {
        return starting
    }
    
    private func nextAnimation(expand: Bool) {
        intervalAnimationsHandler?(self)
        stopAnimationsHandler?(self)
        
        if starting == false {
            return
        }
        
        var count: Double = 0
        if expand == false {
            count = incrementAnimationCount()
        }
        
        let shapeLayer = rotateLayer(count)
        pathLayer = shapeLayer
        indicatorView.layer.addSublayer(shapeLayer)
        
        nextTransaction(expand)
    }
    
    private func nextTransaction(expand: Bool) {
        if expand {
            pathLayer?.addAnimation(contractAnimation(), forKey: ContractAnimationKey)
        } else {
            pathLayer?.addAnimation(groupAnimation(), forKey: GroupAnimationKey)
        }
    }
    
    private func groupAnimation() -> CAAnimationGroup {
        let expand = expandAnimation()
        let contract = contractAnimation()
        expand.beginTime = 0
        contract.beginTime = strokeDuration
        
        let group = CAAnimationGroup()
        group.animations = [expand, contract]
        group.duration = strokeDuration * 2
        group.fillMode = kCAFillModeForwards
        group.removedOnCompletion = false
        group.delegate = self
        
        return group
    }
    
    private func contractAnimation() -> CAPropertyAnimation {
        let anim = CAKeyframeAnimation(keyPath: "strokeStart")
        anim.duration = strokeDuration
        anim.keyTimes = strokeTiming
        anim.values = strokeValues
        anim.fillMode = kCAFillModeForwards
        anim.removedOnCompletion = false
        anim.delegate = self
        
        return anim
    }
    
    private func expandAnimation() -> CAPropertyAnimation {
        let anim = CAKeyframeAnimation(keyPath: "strokeEnd")
        anim.duration = strokeDuration
        anim.keyTimes = strokeTiming
        anim.values = strokeValues
        
        return anim
    }
    
    // MARK: CAAnimation Delegates
    override public func animationDidStop(anim: CAAnimation!, finished flag: Bool) {
        if flag == false {
            let delay = strokeDuration * 2 * Double(NSEC_PER_SEC)
            let time  = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            dispatch_after(time, dispatch_get_main_queue()) {
                self.nextAnimation(false)
            }
        } else {
            self.nextAnimation(false)
        }
    }
}

public extension SpringIndicator {
    public func strokeRatio(ratio: CGFloat) {
        if ratio <= 0 {
            pathLayer = nil
        } else if ratio >= 1 {
            strokeValue(1)
        } else {
            strokeValue(ratio)
        }
    }
    
    private func strokeValue(value: CGFloat) {
        if pathLayer == nil {
            let shapeLayer = rotateLayer(0)
            indicatorView.layer.addSublayer(shapeLayer)
            
            pathLayer = shapeLayer
        }
        
        let anim = stroke(fromValue: 0, toValue: value)
        pathLayer?.addAnimation(anim, forKey: ExpandAnimationKey)
    }
    
    private func stroke(#fromValue: CGFloat, toValue: CGFloat) -> CAPropertyAnimation? {
        let anim = CAKeyframeAnimation(keyPath: "strokeEnd")
        anim.duration = 0
        anim.repeatCount = HUGE
        anim.keyTimes = [0, 0]
        anim.values = [fromValue, toValue]
        anim.fillMode = kCAFillModeBackwards
        return anim
    }
}