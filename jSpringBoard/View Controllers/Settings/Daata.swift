////
////  Daata.swift
////  jSpringBoard
////
////  Created by Derouiche Elyes on 16/01/2022.
////  Copyright © 2022 jota. All rights reserved.
////
//
//import Foundation
//import SwiftUI
//
//struct NFLAllTeams_SportsResponse: Decodable {
//    let sports: [NFLAllTeams_LeaguesResponse]
//}
//struct NFLAllTeams_LeaguesResponse: Decodable {
//    let leagues: [NFLAllTeams_TeamsResponse]
//}
//struct NFLAllTeams_TeamsResponse: Decodable {
//    let teams: [NFLAllTeams_Team] // N:1
//}
//
//// N:1 ) I found this unused in your example so I replace it with NFLAllTeams_Team directly
//struct NFLAllTeams_SingleTeam: Decodable {
//    let team: NFLAllTeams_Team
//}
//struct NFLAllTeams_Team: Decodable {
//    let id: String
//    let location: String
//    let name: String?
//    let nickname: String
//    let abbreviation: String
//    let displayName: String
//    let shortDisplayName: String
//    let isActive: Bool?
//}
//
//
//let fetchedAllTeams : [ NFLAllTeams_SportsResponse ] = []
//
//// N:1
//let allTeams : [NFLAllTeams_Team] = fetchedAllTeams.flatMap { $0.sports.flatMap { $0.leagues } .flatMap { $0.teams } }
//
//struct VMTeam {
//    init( from team : NFLAllTeams_Team ) { }
//}
//
//
//
//
//class EventViewModel: ObservableObject {
//    @Published var vmEvents: [VMEvent] = []
//    @Published var leagueAbbr: String = "NFL"
//    var leagues: [League] = []
//    var calendar: [SeasonSections] = []
//    var events: [Event] = []
//    //MARK: Need to improve logic to populate each drop-down based on the prior ones.
//    @Published var years: [Int] = [2018,2019, 2020, 2021]
//    @Published var seasons = ["Pre-Season", "Reg Season", "Post-Season"]
//    @Published var weeks = ["Wild Card", "Div Rd", "Conf Champ", "Pro Bowl", "Super Bowl"]
//    @Published var isLoading = false
//    @Published var showAlert = false
//    @Published var errorMessage: String?
//    
//    @MainActor
//    func fetchEvents () async {
//        let apiServiceScoreboard = APIService (urlString: K.URL.scoreboardURL)
//        let apiServiceCalendar = APIService (urlString: K.URL.calendarURL)
//        isLoading.toggle()
//        defer {// Waits until function has exited it's scope.
//            isLoading.toggle()
//        }
//        do {
//            async let eventResponse: EventResponse = try await apiServiceScoreboard.getJSON()
//            async let calendarResponse: CalendarResponse
//            = try await apiServiceCalendar.getJSON()
//            let (fetchedEvents,
//                 fetchedCalendars) = await (try eventResponse, try calendarResponse)
//            calendar = fetchedCalendars.sections
//            
//            events = fetchedEvents.events
//            leagues = fetchedEvents.leagues
//            if let index = leagues.firstIndex(where: { !$0.abbr.isEmpty }) {
//                leagueAbbr = leagues[index].abbr
//                vmEvents = []
//                for event in events {
//                    
////                N:2 Variable instances used to beautify code and maybe guard let
//                    let homeCompetitor = event.competitions[0].competitors[0]
//                    let awayCompetitor = event.competitions[0].competitors[1]
//                    
//                    let newEvents = VMEvent(
//                        year: fetchedEvents.season.year,
//                        season: fetchedEvents.season.type,
//                        week: fetchedEvents.week.number,
//                        date: event.date,
//                        name: event.name,
//                        attendance:0,
//                        homeTeamID: Int(homeCompetitor.team.id) ?? 999,
//                        homeName: homeCompetitor.team.name,
//                        displayName : homeCompetitor.team.displayName,
//                        homeDisplayName: homeCompetitor.team.displayName,
//                        homeAbbr:event.homeCompetitor.team.abbr,
//                        homeLogoURL:homeCompetitor.team.logo,
//                        awayTeamID: Int(awayCompetitor.team.id) ?? 998,
//                        awayName: awayCompetitor.team.name,
//                        displayName : awayCompetitor.team.displayName,
//                        awayDisplayName:awayCompetitor.team.displayName,
//                        awayAbbr: awayCompetitor.team.abbr,
//                        awayLogoURL: awayCompetitor.team.logo
//                    )
//                    Events.append (newEvents)
//                }
//                
//            }
//        } catch {
//        }
//    }
//}
//
//// MARK: Used to be passed in the Event ViewModel
//struct VMEvent {
//    var year: Int
//    var season: Int
//    var week: Int
//    var date: Int
//    var name: Int
//    var attendance:Int
//    var homeTeamID: Int
//    var homeName: Int
//    var event : Int
//    var homeDisplayName:Int
//    var homeAbbr:Int
//    var homeLogoURL:Int
//    var awayTeamID: Int
//    var awayName: Int
//    var awayDisplayName:Int
//    var awayAbbr:Int
//    var awayLogoURL:Int
//}
//
//// MARK: This will be passed to each ForEach Row
//class EventRowViewModel: ObservableObject {
//    var vmEvent : VMEvent
//    
//    // specific UI Elements
//    @Published var eventDescription : String
//    @Published var eventName : String
//    @Published var eventDate : String
//    
//    init(from event : VMEvent) {
//        self.eventDescription = "vmEvent. description"
//        self.eventName = "vmEvent. Name"
//        self.eventDate = "vmEvent. Date"
//    }
//}
//
//// MARK: The main TableEvent View
//class MainTableView: View {
//    
//    @StateObject var mainViewModel : EventViewModel
//    
//    var body: some View {
//        ForEach (mainViewModel.vmEvents) {  event in
//            
//            // We pass the EventRowViewModel which takes a single event
//            EventRowView (eventRowViewModel : .init( from : event ) )
//        }
//        .onAppear {
//            mainViewModel.fetchEvents()
//        }
//    }
//}
//
//
//// This Row View will take EventRowViewModel for each VMEvent
//class EventRowView : View {
//    
//    @StateObject var viewModel : EventRowViewModel
//    
//    var body: some View {
//        HStack {
//            // onclick on both images we will redirect
//            NavigationLink (destination: TeamView (VMTeam) ) {
//                Image (uiImage: event.homeCompetitorImage)
//            }
//            
//            NavigationLink (destination: DetailsEventView (viewModel.vmEvent) ) {
//                Text ( viewModel.eventDescription )
//            }
//            
//            NavigationLink (destination: TeamView (VMTeam) ) {
//                Image (uiImage: event.awayCompetitorImage)
//            }
//        }
//    }
//}
