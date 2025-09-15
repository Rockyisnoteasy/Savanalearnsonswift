import SwiftUI

struct FlipCardView: View {
    // 状态管理
    @EnvironmentObject var dictionaryViewModel: DictionaryViewModel
    @State var wordList: [String]
    
    @State private var currentIndex = 0
    @State private var isFlipped = false
    
    // 从Kotlin移植过来的状态
    @State private var currentSentenceInfo: (sentence: String, index: Int?)? = nil

    // 完成后的回调
    var onSessionComplete: () -> Void

    // 返回操作
    var onBack: () -> Void
    
    var body: some View {
        if wordList.isEmpty {
            VStack {
                Text("正在加载单词...")
                ProgressView()
            }
            .onAppear {
                // 如果列表为空，直接调用完成回调
                onSessionComplete()
            }
        } else if currentIndex < wordList.count {
            let word = wordList[currentIndex]
            
            VStack {
                // 顶部进度条
                HStack {
                    Text("\(currentIndex + 1)/\(wordList.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    // 暂时放置一个占位符，后续实现熟悉度逻辑
                    Text("熟悉度：○")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()

                // 卡片区域
                ZStack {
                    // 根据isFlipped状态决定显示正面还是背面
                    if !isFlipped {
                        FrontCardView(
                            word: word,
                            sentence: currentSentenceInfo?.sentence
                        )
                    } else {
                        BackCardView(
                            fullDefinition: dictionaryViewModel.getDefinition(for: word) ?? "无释义",
                            shortDefinition: dictionaryViewModel.getSimplifiedDefinition(for: word)
                        )
                    }
                }
                .modifier(FlipEffect(flipped: $isFlipped, angle: isFlipped ? 180 : 0, axis: (x: 0, y: 1)))
                .onTapGesture {
                    withAnimation(.spring()) {
                        isFlipped.toggle()
                    }
                }
                
                Spacer()

                // 底部控制按钮
                HStack(spacing: 40) {
                    IconTextButton(iconName: "speaker.wave.2.fill", label: "朗读") {
                        // TODO: 实现朗读逻辑
                    }
                    
                    IconTextButton(iconName: "arrow.triangle.2.circlepath", label: "翻面") {
                        withAnimation(.spring()) {
                            isFlipped.toggle()
                        }
                    }
                    
                    IconTextButton(iconName: "arrow.right", label: "继续") {
                        goToNextWord()
                    }
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarBackButtonHidden(true) // 隐藏默认返回按钮
            .toolbar { // 自定义返回按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
            .onAppear {
                fetchSentenceAndPlayAudio(for: word)
            }
        }
    }
    
    private func goToNextWord() {
        if currentIndex < wordList.count - 1 {
            // 翻回正面
            if isFlipped {
                withAnimation {
                    isFlipped = false
                }
                // 延迟一下再切换单词，让用户看到翻转动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    currentIndex += 1
                    fetchSentenceAndPlayAudio(for: wordList[currentIndex])
                }
            } else {
                currentIndex += 1
                fetchSentenceAndPlayAudio(for: wordList[currentIndex])
            }
            
        } else {
            // 已经是最后一个单词，结束session
            onSessionComplete()
        }
    }
    
    private func fetchSentenceAndPlayAudio(for word: String) {
        // Kotlin代码中是在后台线程获取例句
        DispatchQueue.global().async {
            let sentencePair = dictionaryViewModel.getRandomEnglishSentence(for: word)
            DispatchQueue.main.async {
                self.currentSentenceInfo = sentencePair
                // TODO: 实现音频播放逻辑
                // viewModel.playWordAndThenSentence(word, sentenceToPlay, context)
            }
        }
    }
}

// 卡片正面
struct FrontCardView: View {
    let word: String
    let sentence: String?

    var body: some View {
        VStack {
            Text(word)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()

            if let sentence = sentence {
                Text(sentence)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.darkGray))
        .cornerRadius(24)
    }
}

// 卡片背面
struct BackCardView: View {
    let fullDefinition: String
    let shortDefinition: String
    @State private var expanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(expanded ? fullDefinition : shortDefinition)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding()

                if !expanded {
                    Button(action: { expanded = true }) {
                        Text("↓ 展开全部释义")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.darkGray))
        .cornerRadius(24)
        .rotation3DEffect(Angle(degrees: 180), axis: (x: 0, y: 1, z: 0)) // 背面内容需要翻转回来
    }
}

// 底部带图标的按钮
struct IconTextButton: View {
    let iconName: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        VStack {
            Button(action: action) {
                Image(systemName: iconName)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            Text(label)
                .font(.caption)
        }
    }
}

// 翻转动画效果
struct FlipEffect: GeometryEffect {
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    
    @Binding var flipped: Bool
    var angle: Double
    let axis: (x: CGFloat, y: CGFloat)
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        // 移除 DispatchQueue.main.async 的副作用
        // 让 `isFlipped` 状态的改变驱动视图，而不是反过来
        // isFlipped 的值由 onTapGesture 控制，这里只负责根据角度计算动画

        let a = CGFloat(Angle(degrees: angle).radians)

        var transform3d = CATransform3DIdentity
        transform3d.m34 = -1 / max(size.width, size.height)

        transform3d = CATransform3DRotate(transform3d, a, axis.x, axis.y, 0)
        transform3d = CATransform3DTranslate(transform3d, -size.width/2.0, -size.height/2.0, 0)

        let affineTransform = ProjectionTransform(CGAffineTransform(translationX: size.width/2.0, y: size.height/2.0))

        return ProjectionTransform(transform3d).concatenating(affineTransform)
    }
}
