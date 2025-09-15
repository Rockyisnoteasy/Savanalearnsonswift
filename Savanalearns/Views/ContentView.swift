// Savanalearns/Views/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isDrawerOpen = false
    
    
    var body: some View {

        if authViewModel.isLoggedIn {
            NavigationView {
                ZStack(alignment: .leading) { // 1. 添加 alignment: .leading
                    HomeView(authViewModel: authViewModel)
                        // 2. 在 HomeView 上添加拖动手势
                        .gesture(
                            DragGesture().onEnded { value in
                                // 如果向右滑动超过 100 像素
                                if value.translation.width > 100 {
                                    withAnimation(.easeInOut) {
                                        isDrawerOpen = true
                                    }
                                }
                            }
                        )

                    // 抽屉菜单和背景遮罩
                    SideMenu(isOpen: $isDrawerOpen)
                }
                .navigationBarItems(leading:
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isDrawerOpen.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                    }
                )
            }
        } else {
            LoginView(viewModel: authViewModel)
        }
        
    }
}

// 将抽屉和遮罩封装成一个独立的组件
struct SideMenu: View {
    @Binding var isOpen: Bool
    
    var body: some View {
        // ZStack 让遮罩和菜单可以重叠
        ZStack {
            // 当抽屉打开时，显示半透明遮罩
            if isOpen {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isOpen = false
                        }
                    }
            }
            
            // 抽屉视图本身
            SideMenuView { menuItem in
                print("\(menuItem) tapped")
                withAnimation(.easeInOut) {
                    isOpen = false
                }
            }
            .frame(width: 250) // 设置抽屉宽度
            .gesture(
                DragGesture().onEnded { value in
                    // 如果向左滑动超过 100 像素
                    if value.translation.width < -100 {
                        withAnimation(.easeInOut) {
                            isOpen = false
                        }
                    }
                }
            )
            .offset(x: isOpen ? 0 : -250)
            // 2. 添加这一行来强制 ZStack 左对齐
            .frame(maxWidth: .infinity, alignment: .leading) 
        }
    }
}


#Preview {
    ContentView()
}
