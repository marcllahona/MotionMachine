//
//  ValueAssistantGroup.swift
//  MotionMachine
//
//  Created by Brett Walker on 5/18/16.
//  Copyright © 2016 Poet & Mountain, LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// The `ValueAssistantGroup` class enables multiple `ValueAssistant` objects to be attached to a single motion class.
public class ValueAssistantGroup : ValueAssistant {
    
    public var additive: Bool = false {
        didSet {
            for index in 0 ..< assistants.count {
                assistants[index].additive = additive
            }
        }
    }
    public var additiveWeighting: Double = 1.0 {
        didSet {
            // constrain weighting to range of 0.0 - 1.0
            additiveWeighting = max(min(additiveWeighting, 1.0), 0.0)
            
            for index in 0 ..< assistants.count {
                assistants[index].additiveWeighting = additiveWeighting
            }
        }
    }
    
    private(set) public var assistants: [ValueAssistant] = []
    
    /**
     *  Initializer.
     *
     *  - parameters:
     *      - assistants: An optional array of `ValueAssistant` objects to which the ValueAssistantGroup should delegate `ValueAssistant` method calls.
     */
    public init(assistants: [ValueAssistant]? = []) {
        
        if let unwrapped_assists = assistants {
            self.assistants = unwrapped_assists
        }
        
    }
    
    
    // MARK: Public Methods
    
    /**
     *  Adds a `ValueAssistant` to the group.
     *
     *  - parameter assistant: A `ValueAssistant` object.
     *  - note: The added assistant will be assigned the same values for `additive` and `additiveWeighting` as this group's values.
     *  - seealso: additive, additiveWeighting
     */
    public func add(assistant: ValueAssistant) {
        var assist = assistant

        assist.additive = additive
        assist.additiveWeighting = additiveWeighting
        assistants.append(assist)
    }
    
    
    // MARK: ValueAssistant methods
    
    public func generateProperties(fromObject object: AnyObject, keyPath path: String, targetObject target: AnyObject) -> [PropertyData] {
        var properties: [PropertyData] = []
        
        for assistant in assistants {
            if (assistant.supports(object)) {
                if let generated = try? assistant.generateProperties(fromObject: object, keyPath: path, targetObject: target) {
                    properties = generated
                    break
                }
            }
        }
        
        return properties
    }
    
    
    public func retrieveValue(inObject object: AnyObject, keyPath path: String) -> Double? {
        var retrieved_value: Double?
        
        for assistant in assistants {
            if (assistant.supports(object)) {
                if let retrieved = try? assistant.retrieveValue(inObject: object, keyPath: path) {
                    retrieved_value = retrieved
                    break
                }
            }
        }
        
        if (retrieved_value == nil) {
            let path_value = object.valueForKeyPath(path)!
            
            // cast numeric value to a double
            retrieved_value = MotionSupport.cast(path_value)
            
            let components = path.componentsSeparatedByString(".")
            
            
            let first_component = components.first!
            let child_object = object.valueForKey(first_component)
            if let unwrapped_child = child_object {
                if (acceptsKeypath(unwrapped_child)) {
                    
                }
            }
        
        }
        
        return retrieved_value
    }
    
    
    public func updateValue(inObject object: AnyObject, newValues: Dictionary<String, Double>) -> NSObject? {
        
        guard newValues.count > 0 else { return nil }
        
        var new_parent_value:NSObject?
        
        for assistant in assistants {
            if (assistant.supports(object)) {
                new_parent_value = assistant.updateValue(inObject: object, newValues: newValues)
                break
            }
        }
     
        return new_parent_value
    }
    
    
    public func retrieveCurrentObjectValue(forProperty property: PropertyData) -> Double? {
        
        guard let unwrapped_target = property.target else { return nil }

        var current_value: Double?
        
        for assistant in assistants {
            if (assistant.supports(unwrapped_target)) {
                current_value = assistant.retrieveCurrentObjectValue(forProperty: property)
                break
            }
        }

    
        return current_value
        
    }
    
    
    
    public func calculateValue(forProperty property: PropertyData, newValue: Double) -> NSObject? {
        
        guard let unwrapped_target = property.target else { return nil }
        
        var new_prop: NSObject? = NSNumber.init(double: property.current)
        
        // this code path will execute if the object passed in was an NSValue
        // as such we must replace the value object directly
        if ((property.targetObject == nil || property.targetObject === unwrapped_target) && unwrapped_target is NSValue) {
            for assistant in assistants {
                if (assistant.supports(unwrapped_target)) {
                    new_prop = assistant.calculateValue(forProperty: property, newValue: newValue)
                    if (new_prop != nil) { break }
                }
            }
            
            return new_prop
        }
        
        
        if (property.targetObject != nil) {
            // we have a normal object whose property is being changed
            for assistant in assistants {
                if (assistant.supports(unwrapped_target)) {
                    new_prop = assistant.calculateValue(forProperty: property, newValue: newValue)
                    break
                }
            }
            
            return new_prop
        
        } else {
            
            // we have no base object as it's not a NSValue, so find assistant that supports target
            // this will typically be a UIColor
            for assistant in assistants {
                if (assistant.supports(unwrapped_target)) {
                    new_prop = assistant.calculateValue(forProperty: property, newValue: newValue)
                    break
                }
            }
        }
        
        
        return new_prop
    }
    
    
    
    public func supports(object: AnyObject) -> Bool {
        var is_supported: Bool = false
        
        for assistant in assistants {
            is_supported = assistant.supports(object)
            
            if (is_supported) { break }
        }
        
        return is_supported
    }
    
    
    public func acceptsKeypath(object: AnyObject) -> Bool {
        var accepts = true
        
        for assistant in assistants {
            if (!assistant.acceptsKeypath(object) && assistant.supports(object)) {
                accepts = false
                break
            }
        }
        return accepts
    }
    
}