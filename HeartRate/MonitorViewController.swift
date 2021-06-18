//
//  MonitorViewController.swift
//  View Controller that shows the history of heart rate messages from the watch,
//  including a simple chart showing the last 10 readings
//
//  Created by Jonny on 10/25/16.
//  Updating for Blockchain Healthcare project by Jit - started Feb 1, 2021
//  Copyright © 2016 Jonny. All rights reserved.
//

import UIKit

class MonitorViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    final let pantherchainbaseurl = "https://pantherchain.fiu.edu/PantherChain/"
    final let defaultkeysig = "f4dca";

    var avgheart = 0
    var numreadings = 0
    var starttick = 0
    var public_key_value:String?
    var private_key_value:String?
    var keysig:String?

    // Enumerated datatype to store the different monitor states
    enum MonitorState {
        case notStarted, launching, running, errorOccur(Error)
    }
    
    // MARK: - Properties
    
    // Ok this is a property of the viewcontroller - monitorState of type Monitorstate
    // looks like default value is notStarted - and has a setter embedded
    // This is cool - just setting a property also make changes to the UI.
    var monitorState = MonitorState.notStarted {
        didSet {
            DispatchQueue.main.async {
                print("monitorState", self.monitorState)
                
                switch self.monitorState {
                case .notStarted:
                    self.title = "Ready to Start"
                    self.startStopBarButtonItem.title = "Start"
                case .launching:
                    self.title = "Launching Watch App"
                    self.startStopBarButtonItem.title = "Stop"
                case .running:
                    self.title = "Monitoring"
                    self.startStopBarButtonItem.title = "Stop"
                case .errorOccur:
                    self.title = "Error"
                    self.startStopBarButtonItem.title = "Start"
                }
            }
        }
    }
    
    
    // Outlet property of the table - why is didSet in this one? Shouldn't this be set from
    // the storyboard?
    @IBOutlet private var tableView: UITableView! {
        didSet {
            tableView.dataSource = self
            tableView.delegate = self
            tableView.scrollIndicatorInsets.top = tableViewHeaderHeight
        }
    }
    
    @IBOutlet weak var actionButtonItem: UIBarButtonItem!
    
    @IBOutlet private var startStopBarButtonItem: UIBarButtonItem!
    
    // How high the tableviewheader is - manually set??
    private let tableViewHeaderHeight: CGFloat = 44 * 3
    
    // HeartRateManager is a model class to save heartrate records
    private let heartRateManager = HeartRateManager()
    
    // This allows us to check if the watch is connected.
    private var messageHandler: WatchConnectivityManager.MessageHandler?
    
    // No idea what "lazy" var is? Some kind of on demand variable that is calculated
    // by a function at runtime - and only when used.
    private lazy var tableViewHeaderView: UIView = { [unowned self] in
        
        // Create the header of the table that shows an image represenging a chart of the data
        let headerView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        headerView.contentView.addSubview(self.chartImageView)
        
        self.chartImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.chartImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            //  self.chartImageView.topAnchor.constraint(equalTo: headerView.topAnchor),
            self.chartImageView.topAnchor.constraint(equalTo: headerView.centerYAnchor, constant: -24),
            self.chartImageView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            self.chartImageView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
        ])
        
        // Add a line to separate the chart from the table
        let seperatorLine = UIView()
        seperatorLine.backgroundColor = UIColor(red: 200/255, green: 199/255, blue: 204/255, alpha: 1)
        headerView.contentView.addSubview(seperatorLine)
        
        seperatorLine.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            seperatorLine.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            seperatorLine.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            seperatorLine.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            seperatorLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.nativeScale),
            ])
        
        return headerView
    }()
    
    private let chartImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    // Heartratechartgenerator is a chart using YoLineImageKit (Pod is available but the project does not use it)
    private let heartRateChartGenerator: YOLineChartImage = {
        
        let chartGenerator = YOLineChartImage()
        
        chartGenerator.strokeWidth = 2.0
        chartGenerator.strokeColor = .black
        chartGenerator.fillColor = .clear // UIColor.white.withAlphaComponent(0.4)
        chartGenerator.pointColor = .black
        chartGenerator.isSmooth = true
        
        return chartGenerator
    }()
    
    
    // MARK: - View Controller Lifecycle
    
    deinit {
        print("deinit \(type(of: self))")
        // invalidate the messageHandler
        messageHandler?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Handler for when heartRateManager updates - update the table and chart
        // enable trash button if records are present
        heartRateManager.recordsUpdateHandler = { records in
            self.tableView.reloadData()
            self.updateChartIfNeeded()
            self.actionButtonItem.isEnabled = !records.isEmpty
        }
        
        // First load - update chart - maybe this will show where data is stored (?)
        self.updateChartIfNeeded()
        
        // Handle session messages between iPhone and Apple Watch.
        guard let manager = WatchConnectivityManager.shared else {
            // if the current device don't support Watch Connectivity framework, disable the start/stop button.
            startStopBarButtonItem.isEnabled = false
            title = "No watch available"
            return
        }
        
        // set up the message Handler to get messages from the watch and react appropriately
        messageHandler = WatchConnectivityManager.MessageHandler { [weak self] message in
            // What does this line mean??? why would self be weak?
            guard let `self` = self else { return }
            
            // I need to monitor the prints
            print("Message received: \(message)")
            print("\n")
            
            // What kinds of things will be in message? What if the watch app is started without the
            // iOS app? Are we going to still get the messages?
            if let intergerValue = message[.heartRateIntergerValue] as? Int,
                let recordDate = message[.heartRateRecordDate] as? Date {
                
                let newRecord = HeartRateRecord(intergerValue: intergerValue, recordDate: recordDate)
                self.heartRateManager.save([newRecord])
                self.monitorState = .running
                
                //  self.heartRateRecords.insert(newRecord, at: 0)
                //  self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                //  self.updateChartIfNeeded()
            }
            else if message[.workoutStop] != nil{
                self.monitorState = .notStarted
            }
            else if message[.workoutStart] != nil{
                self.monitorState = .running
            }
            else if let errorData = message[.workoutError] as? Data {
                if let error = NSKeyedUnarchiver.unarchiveObject(with: errorData) as? Error {
                    self.monitorState = .errorOccur(error)
                }
            }
        }
        manager.addMessageHandler(messageHandler!)
        
        keysig = UserDefaults.standard.string(forKey: "pref_pk")
        if (keysig == nil) {
            keysig = defaultkeysig
        }
        
        let url = URL(string: "\(pantherchainbaseurl)getKey?key=\(keysig!)")!
        let task = URLSession.shared.dataTask(with: url) { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            // Parse the data in the response and use it
            guard let data = data, error == nil else { return }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:Any]
                self.public_key_value = json["publicKey"] as? String ?? nil
                self.private_key_value = json["privateKey"] as? String ?? nil
                DispatchQueue.main.async {
                    self.showToast(message: "Pub key: \(self.public_key_value ?? "NO PUBLIC KEY")", seconds: 1.0)
                }
            } catch let error as NSError {
                print(error)
                DispatchQueue.main.async {
                    self.showToast(message: "Invalid PK signature - pleas see settings", seconds: 1.0)
                }
            }
        }
        task.resume()
    }
    
    // I have never used this one before - what does this do?
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateChartIfNeeded() }, completion: nil)
    }
    
    
    // MARK: - UI Updates
    
    // Update the chart
    private func updateChartIfNeeded() {
        
        let heartRateRecords = heartRateManager.records
        
        // The framework require at least 2 point to draw a line chart.
        guard heartRateRecords.count >= 2 else {
            // chear chart
            chartImageView.image = nil
            return
        }
        
        // the records are sorted from new to old
        var integers = heartRateRecords.map { $0.intergerValue }
        
        // Only shows recent 10 heart rate records on chart.
        let maximumShowsCount = 10
        
        if integers.count > maximumShowsCount {
            integers = (integers as NSArray).subarray(with: NSMakeRange(0, maximumShowsCount)) as! [Int]
            integers = Array(integers.reversed())
        }
        
        // let minimunInteger = 40 // integers.min()!
        
        let numbers = integers.map { NSNumber(integerLiteral: $0) }
        
        self.heartRateChartGenerator.values = numbers

        let uiImage = self.heartRateChartGenerator.draw(in: chartImageView.bounds, scale: UIScreen.main.scale, edgeInsets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)) // draw an image
        
        chartImageView.image = uiImage
    }
    
    
    // MARK: - UITableViewDataSource, UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return heartRateManager.records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(UITableViewCell.self)", for: indexPath)
        let record = heartRateManager.records[indexPath.row]
        
        cell.textLabel?.text = "\(record.intergerValue)"
        cell.detailTextLabel?.text = DateFormatter.localizedString(from: record.recordDate,
                                                                   dateStyle: .none, timeStyle: .medium)
        
        let font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: UIFont.Weight.regular)
        cell.textLabel?.font = font
        
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.regular)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return tableViewHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableViewHeaderView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    // MARK: - Actions
    
    @IBAction func actionButtonItemDidTap(_ sender: Any) {
        
        let controller = UIAlertController(title: "Submit workout", message: "This will send your workout to the blockchain and delete the data from your device. This cannot be undone.", preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "Submit", style: .destructive) { _ in

            // create post request
            let url = URL(string: "\(self.pantherchainbaseurl)addJson")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            var urlComponents = URLComponents()
            let q1 = URLQueryItem(name: "publicKey", value: self.public_key_value ?? "NO KEY")
            let hrsummary = self.heartRateManager.getSummary()
            let q2 = URLQueryItem(name: "jsonData",
                                  value: "{\"source\":\"HRMiOS\",\(hrsummary)}")
            urlComponents.queryItems = [q1, q2]
            let payload = urlComponents.percentEncodedQuery!.data(using: .utf8)
            
            let task = URLSession.shared.uploadTask(with: request, from:payload) { data, response, error in
                guard let data = data, error == nil else {
                    print(error?.localizedDescription ?? "No data")
                    return
                }
                let str = String(data: data, encoding: .utf8)!
                print(str)
                DispatchQueue.main.async {
                    self.showToast(message: str, seconds: 2.0)
                }
            }

            task.resume()
            self.heartRateManager.deleteAllRecords()
        })
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(controller, animated: true)
    }
    
    @IBAction func startStopButtonItemDidTap(_ sender: UIBarButtonItem) {
        
        if sender.title == "Start" {
            monitorState = .launching
            heartRateManager.startWatchApp { error in
                if let error = error {
                    self.monitorState = .errorOccur(error)
                }
            }
        }
        else {
            monitorState = .notStarted
            
            guard let wcManager = WatchConnectivityManager.shared else { return }
            
            wcManager.fetchReachableState { isReachable in
                if isReachable {
                    wcManager.send([.workoutStop : true])
                } else {
                    wcManager.transfer([.workoutStop : true])
                }
            }
        }
    }
}
