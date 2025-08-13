/*
 * 快速中值计算模块
 * 
 * 基于三分法的快速中值算法：
 * 1. 将输入数组三等分
 * 2. 每组找出最大值、最小值、中值
 * 3. 在三个组的代表值中找最终中值
 * 
 * 适用于最多8个有效数据的中值计算
 */

module Fast_Median_Calculator #(
    parameter DATA_WIDTH = 16,    // 数据位宽
    parameter MAX_COUNT = 8       // 最大数据个数
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        valid_in,
    input  wire [DATA_WIDTH-1:0]       data_array [0:MAX_COUNT-1],  // 输入数据数组
    input  wire [3:0]                  valid_count,                 // 有效数据个数
    
    output reg                         valid_out,
    output reg  [DATA_WIDTH-1:0]       median_out,
    output reg  [DATA_WIDTH-1:0]       center_out //还没加
);

    // 内部寄存器
    reg [DATA_WIDTH-1:0] group1 [0:2];  // 第一组（最多3个）
    reg [DATA_WIDTH-1:0] group2 [0:2];  // 第二组（最多3个）
    reg [DATA_WIDTH-1:0] group3 [0:1];  // 第三组（最多2个）
    reg [1:0] group1_count, group2_count, group3_count;
    
    // 各组的最大值、最小值、中值
    reg [DATA_WIDTH-1:0] group1_max, group1_min, group1_mid;
    reg [DATA_WIDTH-1:0] group2_max, group2_min, group2_mid;
    reg [DATA_WIDTH-1:0] group3_max, group3_min, group3_mid;
    
    // 流水线状态
    reg stage1_valid, stage2_valid;
    reg [3:0] valid_count_d1, valid_count_d2;
    
    integer i;
    
    // 阶段1：数据分组
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid <= 0;
            valid_count_d1 <= 0;
            group1_count <= 0;
            group2_count <= 0;
            group3_count <= 0;
            for (i = 0; i < 3; i = i + 1) begin
                group1[i] <= 0;
                group2[i] <= 0;
                if (i < 2) group3[i] <= 0;
            end
        end
        else begin
            stage1_valid <= valid_in;
            valid_count_d1 <= valid_count;
            
            if (valid_in) begin
                // 清空分组
                for (i = 0; i < 3; i = i + 1) begin
                    group1[i] <= 0;
                    group2[i] <= 0;
                    if (i < 2) group3[i] <= 0;
                end
                
                // 按3个一组进行分组
                case (valid_count)
                    1: begin
                        group1[0] <= data_array[0];
                        group1_count <= 1;
                        group2_count <= 0;
                        group3_count <= 0;
                    end
                    
                    2: begin
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1_count <= 2;
                        group2_count <= 0;
                        group3_count <= 0;
                    end
                    
                    3: begin
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1[2] <= data_array[2];
                        group1_count <= 3;
                        group2_count <= 0;
                        group3_count <= 0;
                    end
                    
                    4: begin
                        // 第1组：3个，第2组：1个
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1[2] <= data_array[2];
                        group2[0] <= data_array[3];
                        group1_count <= 3;
                        group2_count <= 1;
                        group3_count <= 0;
                    end
                    
                    5: begin
                        // 第1组：3个，第2组：2个
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1[2] <= data_array[2];
                        group2[0] <= data_array[3];
                        group2[1] <= data_array[4];
                        group1_count <= 3;
                        group2_count <= 2;
                        group3_count <= 0;
                    end
                    
                    6: begin
                        // 第1组：3个，第2组：3个
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1[2] <= data_array[2];
                        group2[0] <= data_array[3];
                        group2[1] <= data_array[4];
                        group2[2] <= data_array[5];
                        group1_count <= 3;
                        group2_count <= 3;
                        group3_count <= 0;
                    end
                    
                    7: begin
                        // 第1组：3个，第2组：3个，第3组：1个
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1[2] <= data_array[2];
                        group2[0] <= data_array[3];
                        group2[1] <= data_array[4];
                        group2[2] <= data_array[5];
                        group3[0] <= data_array[6];
                        group1_count <= 3;
                        group2_count <= 3;
                        group3_count <= 1;
                    end
                    
                    8: begin
                        // 第1组：3个，第2组：3个，第3组：2个
                        group1[0] <= data_array[0];
                        group1[1] <= data_array[1];
                        group1[2] <= data_array[2];
                        group2[0] <= data_array[3];
                        group2[1] <= data_array[4];
                        group2[2] <= data_array[5];
                        group3[0] <= data_array[6];
                        group3[1] <= data_array[7];
                        group1_count <= 3;
                        group2_count <= 3;
                        group3_count <= 2;
                    end
                    
                    default: begin
                        group1_count <= 0;
                        group2_count <= 0;
                        group3_count <= 0;
                    end
                endcase
            end
        end
    end
    
    // 阶段2：各组内部排序找最大最小中值
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_valid <= 0;
            valid_count_d2 <= 0;
            group1_max <= 0; group1_min <= 0; group1_mid <= 0;
            group2_max <= 0; group2_min <= 0; group2_mid <= 0;
            group3_max <= 0; group3_min <= 0; group3_mid <= 0;
        end
        else begin
            stage2_valid <= stage1_valid;
            valid_count_d2 <= valid_count_d1;
            
            if (stage1_valid) begin
                // 处理第1组
                case (group1_count)
                    0: begin
                        group1_max <= 0;
                        group1_min <= 0;
                        group1_mid <= 0;
                    end
                    1: begin
                        group1_max <= group1[0];
                        group1_min <= group1[0];
                        group1_mid <= group1[0];
                    end
                    2: begin
                        if (group1[0] <= group1[1]) begin
                            group1_max <= group1[1];
                            group1_min <= group1[0];
                            group1_mid <= (group1[0] + group1[1]) >> 1;
                        end else begin
                            group1_max <= group1[0];
                            group1_min <= group1[1];
                            group1_mid <= (group1[0] + group1[1]) >> 1;
                        end
                    end
                    3: begin
                        // 3个数排序
                        if (group1[0] <= group1[1] && group1[1] <= group1[2]) begin
                            group1_min <= group1[0];
                            group1_mid <= group1[1];
                            group1_max <= group1[2];
                        end else if (group1[0] <= group1[2] && group1[2] <= group1[1]) begin
                            group1_min <= group1[0];
                            group1_mid <= group1[2];
                            group1_max <= group1[1];
                        end else if (group1[1] <= group1[0] && group1[0] <= group1[2]) begin
                            group1_min <= group1[1];
                            group1_mid <= group1[0];
                            group1_max <= group1[2];
                        end else if (group1[1] <= group1[2] && group1[2] <= group1[0]) begin
                            group1_min <= group1[1];
                            group1_mid <= group1[2];
                            group1_max <= group1[0];
                        end else if (group1[2] <= group1[0] && group1[0] <= group1[1]) begin
                            group1_min <= group1[2];
                            group1_mid <= group1[0];
                            group1_max <= group1[1];
                        end else begin
                            group1_min <= group1[2];
                            group1_mid <= group1[1];
                            group1_max <= group1[0];
                        end
                    end
                endcase
                
                // 处理第2组（同样的逻辑）
                case (group2_count)
                    0: begin
                        group2_max <= 0;
                        group2_min <= 0;
                        group2_mid <= 0;
                    end
                    1: begin
                        group2_max <= group2[0];
                        group2_min <= group2[0];
                        group2_mid <= group2[0];
                    end
                    2: begin
                        if (group2[0] <= group2[1]) begin
                            group2_max <= group2[1];
                            group2_min <= group2[0];
                            group2_mid <= (group2[0] + group2[1]) >> 1;
                        end else begin
                            group2_max <= group2[0];
                            group2_min <= group2[1];
                            group2_mid <= (group2[0] + group2[1]) >> 1;
                        end
                    end
                    3: begin
                        // 3个数排序
                        if (group2[0] <= group2[1] && group2[1] <= group2[2]) begin
                            group2_min <= group2[0];
                            group2_mid <= group2[1];
                            group2_max <= group2[2];
                        end else if (group2[0] <= group2[2] && group2[2] <= group2[1]) begin
                            group2_min <= group2[0];
                            group2_mid <= group2[2];
                            group2_max <= group2[1];
                        end else if (group2[1] <= group2[0] && group2[0] <= group2[2]) begin
                            group2_min <= group2[1];
                            group2_mid <= group2[0];
                            group2_max <= group2[2];
                        end else if (group2[1] <= group2[2] && group2[2] <= group2[0]) begin
                            group2_min <= group2[1];
                            group2_mid <= group2[2];
                            group2_max <= group2[0];
                        end else if (group2[2] <= group2[0] && group2[0] <= group2[1]) begin
                            group2_min <= group2[2];
                            group2_mid <= group2[0];
                            group2_max <= group2[1];
                        end else begin
                            group2_min <= group2[2];
                            group2_mid <= group2[1];
                            group2_max <= group2[0];
                        end
                    end
                endcase
                
                // 处理第3组
                case (group3_count)
                    0: begin
                        group3_max <= 0;
                        group3_min <= 0;
                        group3_mid <= 0;
                    end
                    1: begin
                        group3_max <= group3[0];
                        group3_min <= group3[0];
                        group3_mid <= group3[0];
                    end
                    2: begin
                        if (group3[0] <= group3[1]) begin
                            group3_max <= group3[1];
                            group3_min <= group3[0];
                            group3_mid <= (group3[0] + group3[1]) >> 1;
                        end else begin
                            group3_max <= group3[0];
                            group3_min <= group3[1];
                            group3_mid <= (group3[0] + group3[1]) >> 1;
                        end
                    end
                endcase
            end
        end
    end
    
    // 阶段3：在三个组的代表值中找最终中值
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            median_out <= 0;
        end
        else begin
            valid_out <= stage2_valid;
            
            if (stage2_valid) begin
                case (valid_count_d2)
                    0: median_out <= 0;
                    1: median_out <= group1_mid;
                    2: median_out <= (group1_mid + group2_mid) >> 1;
                    default: begin
                        // 在三个代表值中找中值：max的min, min的max, mid的mid
                        reg [DATA_WIDTH-1:0] candidate1, candidate2, candidate3;
                        
                        // 获取候选值
                        candidate1 = (group1_max < group2_max) ? ((group1_max < group3_max) ? group1_max : group3_max) : ((group2_max < group3_max) ? group2_max : group3_max);  // max的min
                        candidate2 = (group1_min > group2_min) ? ((group1_min > group3_min) ? group1_min : group3_min) : ((group2_min > group3_min) ? group2_min : group3_min);  // min的max
                        candidate3 = group1_mid;  // 假设第1组的中值作为整体中值的候选
                        
                        // 在三个候选值中找中值
                        if (candidate1 <= candidate2 && candidate2 <= candidate3) begin
                            median_out <= candidate2;
                        end else if (candidate1 <= candidate3 && candidate3 <= candidate2) begin
                            median_out <= candidate3;
                        end else if (candidate2 <= candidate1 && candidate1 <= candidate3) begin
                            median_out <= candidate1;
                        end else if (candidate2 <= candidate3 && candidate3 <= candidate1) begin
                            median_out <= candidate3;
                        end else if (candidate3 <= candidate1 && candidate1 <= candidate2) begin
                            median_out <= candidate1;
                        end else begin
                            median_out <= candidate2;
                        end
                    end
                endcase
            end
        end
    end

endmodule
