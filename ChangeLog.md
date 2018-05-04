### TO DO:
1. 改画：应用跳进来时图片作背景呈现；图层需要保存和加载（序列化数据）； !important  加载的painting和设备尺寸不一样  

to do:
1. 转屏
2. painting文件的尺寸和本设备不相同
4. painting的flattenMode
5. 加入drawView对dirty部分rect的绘制
7. 插入图片后的撤销注册操作

bug:
4. 触摸其他popover后应该将当前popover消除

### UPDATED:
1. 修改Canvas的底色设置方式
2. 对screenScale的处理，可提高绘制清晰度
3. Canvas的绘制部分移入到CZCanvas中
4. 更新插入图片的编辑方式
5. 增加画笔大小调整
6. painting的DIC跳转 
7. painting的删除
8. 增加画布变幻复原的手势（双指双击）

- 2018-05-06 【undo&redo逻辑】
    1. 10个undofragment、10个redofragment
    2. 每一笔记录undofragment，最新的一笔记录在undofragment_0
    3. 每画一笔，undofragment整体左移1位（从左侧开始，依次用右1位的值覆盖当前值。EX：undofragmen_9 = unfofragment_8）
    4. 如果undo过程中发生绘画，则根据undo的步数N，undofragment整体右移N位（从右侧开始，依次用右N位的值覆盖当前值。EX：undofragmen_N = unfofragment_0）。这样做的目的是，保证undo之后，对应的undofragment在绘画后被更早的步骤覆盖掉，而不会再次参与到undo中，保证了undofragment都对应于当前的有效的笔画。
    5. redofragment的建立发生在undoAction的过程中，负责把undo发生modify前的img保存下来，用于之后恢复。

- 2016-05-24
    1. 将interface相关的代码独立出来，放在本项目外
    2. 将core中的代码与glsl分开
    3. 删除陈旧代码（CZRender，CZCanvas_original...）

- 2016-05-26
    1. 完善内核的封装，将平台相关的中间层和某些组件封装到库里
    2. 将画布管理功能集成进HYBrushCore，剔除PaintingManager单例
   
- 2016-09-19
	1. 完善内核，修复快速保存当前颜色问题；


### CORE:
1. CZCanvas不仅仅作为core调用view的接口，同时承担着canvas的实体功能，由view去调用。
2. CZLayer的背景图片绘制方法
