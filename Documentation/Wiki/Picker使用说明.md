# Picker 使用说明

本节我们将会详细介绍 `Picker` 中每个配置项的作用，以及一些公开方法。



## 调用/回调说明

`ImagePickerController` 的使用方式与 `UIImagePickerController` 非常类似。

首先我们用三行代码创建并推出选择器。

```swift
let controller = ImagePickerController(options: .init(), delegate: self)
controller.modalPresentationStyle = .fullScreen
present(controller, animated: true, completion: nil)
```

接下来要实现 `ImagePickerControllerDelegate` 中的两个代理方法。

```swift
/// 取消选择（该方法有默认实现，可以省略）
func imagePickerDidCancel(_ picker: ImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
}

/// 完成选择
/// - Parameters:
///   - picker: 图片选择器
///   - result: 返回结果对象，内部包含所选中的图片资源
func imagePicker(_ picker: ImagePickerController, didFinishPicking result: PickerResult) {
    picker.dismiss(animated: true, completion: nil)
    let images: [UIImage] = assets.map{ $0.image }
    // 处理你的业务逻辑
}
```

**注意：** 在两个代理方法中，都需要手动 `dismiss` 控制器。



## 配置项说明

### Theme (PickerTheme)

`theme` 是一个结构体，在结构体内部有许多 `UIColor` 类型的属性，你可以自定义一些颜色来改变 `Picker` 中的风格。

我们提供了两套配色方案，浅色和深色，但是我们有三种主题，分别是 `auto/light/dark`。

`auto` 主题在 iOS 13 及以上版本中会跟随系统外观改变，在 iOS 13 以下版本中默认为 `light` 主题。

`dark` 主题的样式与微信的图片选择器相似。



### SelectLimit (Int)

`selectLimit` 是可选择的资源数量，默认为 9，即最多可选择 9 张图片/视频。

`selectLimit` 最小值为 1，最大值不限。



### ColumnNumber (Int)

`columnNumber` 是一行可展示的资源数量，默认为 4。

`columnNumber` 最小值为 3，最大值为 5。



### AutoCalculateColumnNumber (Bool)

`autoCalculateColumnNumber` 是否允许自动计算 `columnNumber`，默认**开启**。

在 iOS 平台，一行可展示的资源数量以 `columnNumber` 为准；

在 iPadOS 平台，将根据设备方向、大小进行自动计算。



### AllowUseOriginalImage (Bool)

`allowUseOriginalImage` 是否允许选择“原图”，默认**关闭**。

首先对“原图”打上一对引号，“原图”仅仅是一个文案表示，而非真正意义上的原始图片。

即使开启此属性，`Picker` 的回调方法中也**不会**把原始图片返回，因为原始图片的太大（3-10MB不等）。考虑到性能原因我们会对图片进行压缩后再返回，所以在回调方法中获取到的图片都是经过压缩的，但是我们提供了获取原始图片的方法（后面会介绍），下面我们先来介绍一下在与之相关的另外两个参数。



### PhotoMaxWidth (CGFloat)

`photoMaxWidth` 是**未选中“原图”时**导出的图片最大尺寸，默认为 800。



### LargePhotoMaxWidth (CGFloat)

`largePhotoMaxWidth` 是**选中“原图”时**导出的图片最大尺寸，默认为 1200。

### 

#### 举个例子

对于**普通图片**，使其宽高中的**长边**小于等于指定值。

一张截图的尺寸是：1125x2436 （长边是高：2436）

未选中原图时导出的尺寸是：369x800

选中原图时导出的尺寸是：554x1200



对于**长图**来说（宽高比超过 2.5），使其宽高中**短边**小于等于指定值。

长图尺寸是：828x7951 （短边是宽：828）

未选中原图时导出的尺寸是：800x7682

选中原图时导出的尺寸是：828x7951



### QuickPick (Bool)

`quickPick` 是否允许快速选择，默认关闭。

当开始此属性时，点击图片将直接选中图片，而不会进入预览页面。

当开启此属性且 `selectLimit` 为 1 时，点击图片将直接退出 picker 并触发回调。



### AlbumOptions (PickerAlbumOption)

`albumOptions` 是相册类型，默认为 `[.smart, .userCreated]`。

```swift
struct PickerAlbumOption: OptionSet {
    /// Smart Album, managed by system 智能相册
    static let smart = PickerAlbumOption(rawValue: 1 << 0)
    /// User Created Album 用户相册
    static let userCreated = PickerAlbumOption(rawValue: 1 << 1)
}
```



### SelectOptions (PickerSelectOption)

`PickerSelectOption` 是可选择资源的类型，默认为 `[.photo]`。

```swift
struct PickerSelectOption: OptionSet {
    /// Photo 照片
    static let photo = PickerSelectOption(rawValue: 1 << 0)
    /// Video 视频
    static let video = PickerSelectOption(rawValue: 1 << 1)
    /// GIF 动图
    static let photoGIF = PickerSelectOption(rawValue: 1 << 2)
    /// Live photo 实况照片
    static let photoLive = PickerSelectOption(rawValue: 1 << 3)
}
```

其中 `GIF` 和 `Live Photo` 都归属于 `Photo` 类别下，属于 `Photo` 的子项。

当设置资源类型为 `Photo` 时，`GIF` 和 `Live Photo` 类型的资源会作为普通图片展示出来。

当设置资源类型为 `Photo + GIF` 时，`GIF` 类型的资源会播放。

当设置资源类型为 `Photo + Live Photo` 时，`Live Photo` 类型的资源长按可以播放视频并拥有特定标识。



### OrderByDate (Sort)

`orderByDate` 是排序的类型，默认为 `.asc`。

```swift
enum Sort: Equatable {
    /// ASC 升序
    case asc
    /// DESC 降序
    case desc
}
```

当设置为 `ASC` 时，按时间**升序**排列，自动滚动到**底部**；

当设置为 `desc` 时，按时间**倒序**排列，自动滚动到**顶部**。



### EditorOptions (PickerEditorOption)

`editorOptions` 是可编辑资源的类型，默认为 `[]`，即不能对任何资源进行编辑。

```swift
public struct PickerEditorOption: OptionSet {
    /// Photo 照片
    public static let photo = PickerEditorOption(rawValue: 1 << 0)
    /// Video not finish 视频 未完成
    /*public*/ static let video = PickerEditorOption(rawValue: 1 << 1)
}
```

**注意：**目前只能对图片资源进行编辑，暂不支持对视频编辑。

当设置为 `[.photo]` 时，在预览页面的左下角会出现 ”编辑“ 按钮，点击即可进入 `Editor` 模块对图片进行编辑。



### EditorPhotoOptions (EditorPhotoOptionsInfo)

`editorPhotoOptions` 是 `Editor` 模块的配置项，你可以在[Editor使用说明](https://github.com/AnyImageProject/AnyImageKit/wiki/Editor%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E)中查看详细的介绍。



### CaptureOptions (CaptureOptionsInfo)

`captureOptions` 是 `Capture` 模块的配置项，你可以在[Capture使用说明](https://github.com/AnyImageProject/AnyImageKit/wiki/Capture%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E)中查看详细的介绍。



### UseSameEditorOptionsInCapture (Bool)

`useSameEditorOptionsInCapture` 是在相机中使用相同的编辑配置项，默认开启。

由于 `captureOptions` 内部还有一个 `editorPhotoOptions`，当此配置开启时，会将 `Picker` 中 `editorPhotoOptions` 传入到 `captureOptions` 配置中。



## 公开方法

### 获取原始图片

在 `Picker` 的回调方法中，我们会将 `Asset` 对象返回，在该对象中我们提供了两个获取原始图片的方法：

```swift
func fetchPhotoData(options: PhotoDataFetchOptions = .init(), completion: @escaping PhotoDataFetchCompletion) -> PHImageRequestID
func fetchPhotoURL(options: PhotoURLFetchOptions = .init(), completion: @escaping PhotoURLFetchCompletion) -> PHImageRequestID
```

这两个获取原始图片方法的区别是：

- `fetchPhotoData` 的回调结果是 `Data` 类型。
- `fetchPhotoURL` 的回调结果是 `URL` 类型，你可以在配置项中指定图片临时存放的位置，默认位置是沙盒中的 `tmp` 文件夹。



#### Sample Code

```swift
func imagePicker(_ picker: ImagePickerController, didFinishPicking result: PickerResult) {
    picker.dismiss(animated: true, completion: nil)
    for asset in result.assets {
        asset.fetchPhotoData { (result, requestID) in
            switch result {
            case .success(let response):
                if let image = UIImage(data: response.data) {
                    // Your code
                }
            case .failure(let error):
                print(error)
            }
        }
    }
}
```



### 获取视频

我们在 `Asset` 对象中提供了两个获取视频的方法：

```swift
func fetchVideo(options: VideoFetchOptions = .init(), completion: @escaping VideoFetchCompletion) -> PHImageRequestID
func fetchVideoURL(options: VideoURLFetchOptions = .init(), completion: @escaping VideoURLFetchCompletion) -> PHImageRequestID
```

这两个获取视频方法的区别是：

- `fetchVideo` 的回调结果是 `AVPlayerItem` 类型，可直接用于播放。
- `fetchVideoURL` 的回调结果是 `URL` 类型，你可以在配置项中指定图片临时存放的位置，默认位置是沙盒中的 `tmp` 文件夹。