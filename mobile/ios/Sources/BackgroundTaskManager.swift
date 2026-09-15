import BackgroundTasks
import Foundation

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    let fetchTaskID = "com.local.gallery.fetchUpdates" // Needs to be added to Info.plist / project.yml
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: fetchTaskID, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: fetchTaskID)
        // Schedule for at least 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Successfully scheduled background task: \(fetchTaskID)")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // 1. Schedule the next fetch right away
        scheduleAppRefresh()
        
        // 2. Do the actual fetch (Simulated for Prototype)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        let fetchOperation = BlockOperation {
            // TODO: In the real implementation, this will use URLSession 
            // with the Auth Token we extracted in Ticket 1.
            print("Executing simulated background fetch for Tinder updates...")
            
            // Simulating a network request delay
            Thread.sleep(forTimeInterval: 2.0)
            
            // Trigger a disguised Instagram local notification
            NotificationManager.shared.postDisguisedNotification()
        }
        
        fetchOperation.completionBlock = {
            task.setTaskCompleted(success: !fetchOperation.isCancelled)
        }
        
        queue.addOperation(fetchOperation)
    }
}
