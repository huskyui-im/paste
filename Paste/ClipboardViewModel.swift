//
//  ClipboardViewModel.swift
//  Paste
//
//  Created by 王鹏 on 2025/11/2.
//


// ClipboardViewModel.swift
import Foundation
import Combine

class ClipboardViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var filteredItems: [ClipboardItem] = []
    @Published var showOnlyPinned = false
    
    private let clipboardService: ClipboardService
    private var cancellables = Set<AnyCancellable>()
    
    init(clipboardService: ClipboardService) {
        self.clipboardService = clipboardService
        
        Publishers.CombineLatest($searchText, $showOnlyPinned)
            .sink { [weak self] searchText, showOnlyPinned in
                self?.filterItems(searchText: searchText, showOnlyPinned: showOnlyPinned)
            }
            .store(in: &cancellables)
    }
    
    private func filterItems(searchText: String, showOnlyPinned: Bool) {
        var items = clipboardService.clipboardHistory
        
        if showOnlyPinned {
            // 这里可以添加置顶功能
        }
        
        if !searchText.isEmpty {
            items = items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        
        filteredItems = items
    }
}
