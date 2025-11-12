# DPC Stage2 中值滤波器实现细节文档

## 实现方案详细对比

### 1. 3x3排序网络实现

#### 网络拓扑结构
```
输入: p0, p1, p2, p3, p4, p5, p6, p7 (排除中心p22)

层级1 - 并行比较对:
+-------+  +-------+  +-------+  +-------+
| p0 p1 |  | p2 p3 |  | p4 p5 |  | p6 p7 |
+-------+  +-------+  +-------+  +-------+
    ↓          ↓          ↓          ↓
  (L0,H0)    (L1,H1)    (L2,H2)    (L3,H3)

层级2 - 合并4元组:
  L0 ↘     ↙ L1       L2 ↘     ↙ L3
      Min(L0,L1)          Min(L2,L3)
  H0 ↗     ↘ H1       H2 ↗     ↘ H3  
      Max(H0,H1)          Max(H2,H3)

层级3 - 完整8元素排序:
最终输出: sorted0 ≤ sorted1 ≤ ... ≤ sorted7
中值候选: sorted3 (第4小), sorted4 (第5小)
```

#### 关键代码片段
```verilog
// 比较交换函数
function [WIDTH:0] lo_p;
  input [WIDTH:0] x, y;
  begin 
    lo_p = (x[WIDTH-1:0] <= y[WIDTH-1:0]) ? x : y; 
  end
endfunction

function [WIDTH:0] hi_p;
  input [WIDTH:0] x, y;
  begin 
    hi_p = (x[WIDTH-1:0] <= y[WIDTH-1:0]) ? y : x; 
  end
endfunction

// 第一层排序
wire [WIDTH:0] sA0_0 = lo_p(p0,p1);
wire [WIDTH:0] sA0_1 = hi_p(p0,p1);
// ... 其他对

// 流水线寄存器
always @(posedge aclk) begin
  if (in_valid) begin
    rA0 <= sA2_0; rA1 <= sA2_1; 
    // ... 其他寄存器
  end
end

// 中值选择逻辑
always @(posedge aclk) begin
  if (in_valid) begin
    if (!sorted3[WIDTH])      // sorted3非坏点
      final_med_reg <= sorted3[WIDTH-1:0];
    else if (!sorted4[WIDTH]) // sorted4非坏点
      final_med_reg <= sorted4[WIDTH-1:0];
    else                      // 都是坏点，选择较小值
      final_med_reg <= sorted3[WIDTH-1:0];
  end
end
```

### 2. 5x5两段计数实现

#### 算法原理图解
```
24个邻域像素: N0, N1, N2, ..., N23

对于每个候选Ni:
                    
前12个邻域        后12个邻域
┌─────────────┐   ┌─────────────┐
│ N0...N11    │   │ N12...N23   │
│             │   │             │
│ 计数1: 有多少│   │ 计数2: 有多少│
│ 个 ≤ Ni     │   │ 个 ≤ Ni     │
└─────────────┘   └─────────────┘
       │                 │
       └─────┬───────────┘
             │
      总计数 = 计数1 + 计数2
             │
    如果总计数 = 12 → Ni是第12小
    如果总计数 = 13 → Ni是第13小
```

#### 两段计数实现代码
```verilog
// 第一阶段计数器阵列 (24x12 = 288个比较器)
always @* begin
  for (ia = 0; ia < 24; ia = ia + 1) begin
    cnt_half1[ia] = 0;
    for (jb = 0; jb < 12; jb = jb + 1) begin
      if (r_neigh_pix[jb] <= r_neigh_pix[ia]) 
        cnt_half1[ia] = cnt_half1[ia] + 1'b1;
    end
  end
end

// 第一阶段寄存
always @(posedge aclk) begin
  if (in_valid) begin
    for (ia = 0; ia < 24; ia = ia + 1) 
      r_cnt_half1[ia] <= {1'b0, cnt_half1[ia]};
  end
end

// 第二阶段计数器阵列 (24x12 = 288个比较器)
always @* begin
  for (ia = 0; ia < 24; ia = ia + 1) begin
    cnt_half2[ia] = 0;
    for (jb = 12; jb < 24; jb = jb + 1) begin
      if (r_neigh_pix[jb] <= r_neigh_pix[ia]) 
        cnt_half2[ia] = cnt_half2[ia] + 1'b1;
    end
  end
end

// 总计数与中值判断
always @* begin
  for (ia = 0; ia < 24; ia = ia + 1) begin
    total_cnt[ia] = r_cnt_half1[ia] + r_cnt_half2[ia];
  end
  
  // 查找第12和第13小的元素
  sel_idx_12 = 0; sel_idx_12_valid = 1'b0;
  sel_idx_13 = 0; sel_idx_13_valid = 1'b0;
  for (ia = 0; ia < 24; ia = ia + 1) begin
    if (total_cnt[ia] == 6'd12 && !sel_idx_12_valid) begin
      sel_idx_12 = ia[4:0]; sel_idx_12_valid = 1'b1;
    end
    if (total_cnt[ia] == 6'd13 && !sel_idx_13_valid) begin
      sel_idx_13 = ia[4:0]; sel_idx_13_valid = 1'b1;
    end
  end
end
```

#### 5x5复杂边界处理详解

##### 边界情况矩阵
```
图像位置类型：
┌────────────────────────────────────┐
│ A  │ B  │ C  │ ... │ D  │ E  │ A  │  A: 角点
├────┼────┼────┼─────┼────┼────┼────┤  B: 第二行/列边界  
│ B  │ F  │ G  │ ... │ H  │ I  │ B  │  C-I: 各种内部边界
├────┼────┼────┼─────┼────┼────┼────┤  F: 正常内部像素
│ C  │ G  │ F  │ ... │ F  │ G  │ C  │
│... │... │... │ ... │... │... │... │
├────┼────┼────┼─────┼────┼────┼────┤
│ B  │ F  │ G  │ ... │ H  │ I  │ B  │
├────┼────┼────┼─────┼────┼────┼────┤
│ A  │ B  │ C  │ ... │ D  │ E  │ A  │
└────────────────────────────────────┘
```

##### e11位置的完整padding逻辑
```verilog
wire [WIDTH-1:0] e11 = 
  // 情况1: 第一行
  is_first_row ? (
    // 1.1: 第一行第一列 → 使用中心w33
    is_first_column ? w33 : (
      // 1.2: 第一行第二列 → 使用w23
      is_2nd_column ? w23 : 
      // 1.3: 第一行其他列 → 使用w21
      w21
    )
  ) : (
    // 情况2: 第二行
    is_2nd_row ? (
      // 2.1: 第二行第一列 → 使用w23
      is_first_column ? w23 : (
        // 2.2: 第二行第二列 → 使用w22  
        is_2nd_column ? w22 : 
        // 2.3: 第二行其他列 → 使用w21
        w21
      )
    ) : (
      // 情况3: 正常内部行
      // 3.1: 第一列 → 使用w13
      is_first_column ? w13 : (
        // 3.2: 第二列 → 使用w12
        is_2nd_column ? w12 : 
        // 3.3: 正常位置 → 使用w11
        w11
      )
    )
  );
```

### 3. 资源使用详细分析

#### 3x3排序网络资源
```
比较器分布:
- 第1层: 4个比较器 (4对并行比较)
- 第2层: 8个比较器 (合并排序)  
- 第3层: 6个比较器 (最终排序)
- 中值选择: 2个比较器
总计: ~20个比较器

寄存器分布:
- 流水线寄存: 8 × (WIDTH+1) × 3级 = 24×(WIDTH+1)
- 延迟匹配: WIDTH × LATENCY_FILTER_FUNC  
- 控制信号: ~10个
总计: ~25×WIDTH + 常数

组合逻辑深度:
- 关键路径: 输入 → 比较器(3级) → 选择器 → 输出
- 延迟估算: ~3-4个LUT级联
```

#### 5x5计数网络资源  
```
比较器分布:
- 第1阶段: 24×12 = 288个比较器
- 第2阶段: 24×12 = 288个比较器  
- 中值判断: 24×2 = 48个比较器
总计: ~624个比较器

寄存器分布:
- 25像素寄存: 25 × (WIDTH+1) × 2级 = 50×(WIDTH+1)
- 24邻域寄存: 24 × (WIDTH+1) × 1级 = 24×(WIDTH+1)  
- 计数寄存: 24 × 6bit × 2级 = 288bit
- 延迟匹配: WIDTH × LATENCY_FILTER_FUNC
总计: ~75×WIDTH + 常数

组合逻辑深度:
- 关键路径: 输入 → Padding(2级) → 计数器(4级) → 判断(2级) → 输出
- 延迟估算: ~8-10个LUT级联
```

### 4. 时序分析

#### 3x3时序时序图
```
时钟:  __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
        0   1   2   3   4   5   6

输入:  [像素A]→[像素B]→[像素C]→[像素D]→[像素E]

阶段1:     [A寄存]→[B寄存]→[C寄存]→[D寄存]→[E寄存]
阶段2:         [A排序A]→[B排序A]→[C排序A]→[D排序A]  
阶段3:             [A排序B]→[B排序B]→[C排序B]
阶段4:                 [A中值]→[B中值]→[C中值]

输出:                      ↑输出A    ↑输出B    ↑输出C
延迟:                      4周期    4周期    4周期
```

#### 5x5时序时序图
```
时钟:  __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
        0   1   2   3   4   5   6   7   8

输入:  [像素A]→[像素B]→[像素C]→[像素D]→[像素E]→[像素F]

阶段1:     [A寄存]→[B寄存]→[C寄存]→[D寄存]→[E寄存]→[F寄存]
阶段2:         [APad]→[BPad]→[CPad]→[DPad]→[EPad]
阶段3:             [A邻域]→[B邻域]→[C邻域]→[D邻域]  
阶段4:                 [A计数1]→[B计数1]→[C计数1]
阶段5:                     [A计数2]→[B计数2]
阶段6:                         [A中值]→[B中值]

输出:                              ↑输出A    ↑输出B
延迟:                              6周期    6周期
```

### 5. 验证与测试

#### Python参考模型核心算法
```python
def compute_median_24(self, window, bad_window):
    """计算24个邻域的中值"""
    # 提取邻域（排除中心[2,2]）
    neighbors = []
    bad_flags = []
    
    for i in range(5):
        for j in range(5):
            if i == 2 and j == 2:  # 跳过中心
                continue
            neighbors.append(window[i, j])
            bad_flags.append(bad_window[i, j])
    
    neighbors = np.array(neighbors)
    bad_flags = np.array(bad_flags)
    
    # 优先选择非坏点
    good_neighbors = neighbors[~bad_flags]
    
    if len(good_neighbors) > 0:
        return np.median(good_neighbors)
    else:
        return np.median(neighbors)

def replicate_padding(self, image, bad_map):
    """5x5边界复制padding"""
    h, w = image.shape
    padded_image = np.zeros((h + 4, w + 4), dtype=image.dtype)
    
    # 复制原始图像到中心
    padded_image[2:h+2, 2:w+2] = image
    
    # 上下边界复制（2层）
    padded_image[0:2, 2:w+2] = image[0:1, :]  # 复制第一行
    padded_image[h+2:h+4, 2:w+2] = image[h-1:h, :]  # 复制最后一行
    
    # 左右边界复制（2层）  
    padded_image[:, 0:2] = padded_image[:, 2:3]  # 复制第一列
    padded_image[:, w+2:w+4] = padded_image[:, w+1:w+2]  # 复制最后一列
    
    return padded_image, padded_bad
```

#### 综合仿真验证点
```verilog
// 边界测试用例
test_cases = [
  // 角点测试
  {pos: (0,0), expect: corner_median},
  {pos: (0,width-1), expect: corner_median},
  {pos: (height-1,0), expect: corner_median}, 
  {pos: (height-1,width-1), expect: corner_median},
  
  // 边界测试  
  {pos: (0,width/2), expect: edge_median},
  {pos: (height-1,width/2), expect: edge_median},
  {pos: (height/2,0), expect: edge_median},
  {pos: (height/2,width-1), expect: edge_median},
  
  // 第二行/列测试
  {pos: (1,1), expect: second_boundary_median},
  {pos: (1,width-2), expect: second_boundary_median},
  
  // 内部测试
  {pos: (height/2,width/2), expect: interior_median}
];
```

### 6. 性能优化建议

#### 3x3优化方向
1. **流水线深度平衡**: 可以考虑3级流水线减少延迟
2. **资源共享**: 复用比较器在不同时钟相位
3. **功耗优化**: 仅在有坏点时启用排序网络

#### 5x5优化方向  
1. **分层计数**: 先8路并行计数，再合并结果
2. **近似中值**: 使用统计方法快速估算中值
3. **自适应窗口**: 根据坏点密度选择3x3或5x5
4. **预计算缓存**: 缓存常见padding模式结果

---

*本文档提供了DPC Stage2中值滤波器3x3和5x5实现的完整技术细节，可作为设计参考和代码审查依据。*