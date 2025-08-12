//���ݷ��ʲ���burstģʽ��burst_read_masterģ��ÿ�ζ�ȡ1�����ݣ�Ȼ���Զ�����control_go�źţ�����������һ�С�
//������ģʽ�£����ڴ��ַ����Ϊwriter_base_index-1��writer_base_indexΪд�߳�����ĵ�ǰд�ڴ��ַ������

//����ַ��ͼ��߶Ⱥ�ͼ���Ⱦ�Ϊ�ź����룬��ʵʱ���ġ�
//����ַ���ĺ󣬵ȴ����л���������0ʱ�Ż���»���ַ��
//ͼ�������ֵΪMAX_WIDTH
//ͼ��߶����ֵΪMAX_HEIGHT

//��ƫ�ƹ̶�Ϊ MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL
//֡��ƫ�ƹ̶�ʽΪ MAX_WIDTH * MAX_HEIGHT * COLOR_PLANE * BYTEPERSYMBOL��


module st_frame_readerII_nuc (
        clk,
        reset_n,

        //control
        go,
        writer_base_index,
        reader_base_index,
        mode,
        baseaddr,
        width,
        height,

        // AXI master inputs and outputs
        m_axi_araddr,
        m_axi_arburst,
        m_axi_arcache,
        m_axi_arlen,
        m_axi_arprot,
        m_axi_arready,
        m_axi_arsize,
        m_axi_aruser,
        m_axi_arvalid,
        m_axi_rdata,
        m_axi_rlast,
        m_axi_rready,
        m_axi_rresp,
        m_axi_rvalid,

        // AXI-ST source
        axis_aclk,
        m_axis_tdata,
        m_axis_tlast,
        m_axis_tvalid,
        m_axis_tready,
        m_axis_tuser

    );

    parameter MAX_WIDTH          = 720;
    parameter MAX_HEIGHT         = 576;
    parameter COLOR_PLANE        = 2;
    parameter BUFFER_NUM         = 3;

    parameter ADDRESSWIDTH       = 32;
    parameter DATAWIDTH_MM       = 64;
    parameter DATAWIDTH_ST       = 8;
    parameter MAXBURSTCOUNT      = 8;
    parameter FIFODEPTH_BYTE     = 2048;

    function integer clogb2 (input integer bit_depth);              
        begin                                                           
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
                bit_depth = bit_depth >> 1;                                 
        end                                                           
    endfunction                                                     

    localparam FIFODEPTH          = FIFODEPTH_BYTE/(DATAWIDTH_MM/8);
    localparam FIFODEPTH_LOG2_MM  = clogb2(FIFODEPTH_BYTE/(DATAWIDTH_MM/8) - 1);   
    localparam FIFODEPTH_LOG2_ST  = clogb2(FIFODEPTH_BYTE/(DATAWIDTH_ST/8) - 1); 
    localparam BURSTCOUNTWIDTH    = clogb2(MAXBURSTCOUNT-1) + 1;
    localparam BYTEENABLEWIDTH    = DATAWIDTH_MM/8; 
    localparam BYTEPERSYMBOL      = DATAWIDTH_ST/8;


    input clk;
    input reset_n;

    input  go;
    input  [3:0] writer_base_index;
    output [3:0] reader_base_index;
    input  [1:0] mode;
    input  [ADDRESSWIDTH-1:0] baseaddr;
    input  [15:0] width;
    input  [15:0] height;

    // AXI master inputs and outputs
    output      [ADDRESSWIDTH-1:0]          m_axi_araddr;
    output      [1:0]                       m_axi_arburst;
    output      [3:0]                       m_axi_arcache;
    output      [7:0]                       m_axi_arlen;
    output      [2:0]                       m_axi_arprot;
    input                                   m_axi_arready;
    output      [2:0]                       m_axi_arsize;
    output      [3:0]                       m_axi_aruser;
    output                                  m_axi_arvalid;
    input       [DATAWIDTH_MM-1:0]          m_axi_rdata;
    input                                   m_axi_rlast;
    output                                  m_axi_rready;
    input       [1:0]                       m_axi_rresp;
    input                                   m_axi_rvalid;


    input                                   axis_aclk;
    output      [DATAWIDTH_ST-1 : 0]        m_axis_tdata;
    output                                  m_axis_tlast;
    output                                  m_axis_tvalid;
    input                                   m_axis_tready;
    output                                  m_axis_tuser;


    reg [3:0] base_index;

    reg ready_go;
    reg sync_go;
    reg delay_go;
    reg sync_done;
    reg delay_done;
    reg delay1_done;
    reg delay2_done;

    reg [1:0]  sync_mode;
    reg [15:0] sync_width;
    reg [15:0] sync_height;

    wire sop;
    wire eop;

    reg [15:0] width_counter;
    reg [15:0] height_counter;

    reg  [ADDRESSWIDTH-1:0] read_offset;    
    reg  [ADDRESSWIDTH-1:0] read_base; 

    wire [ADDRESSWIDTH-1:0] control_read_base;    
    wire [ADDRESSWIDTH-1:0] control_read_length;    
    wire control_go;
    wire control_done;

    wire user_read_buffer;                
    wire [DATAWIDTH_ST-1:0] user_buffer_output_data; 
    wire user_data_available;

    wire go_stable;
    assign go_stable = go ? 1'b1 : (height_counter != 1) ? 1'b1 : 1'b0;

    //�໺�����л�����
    always @ (posedge clk or negedge reset_n)
    if(!reset_n) begin 
        read_base  <= baseaddr;
        base_index <= 0;
    end
    else begin
        if ( go_stable && ((delay1_done ^ delay_done) & delay_done) && ( height_counter == 1 ) ) begin     
            if ( BUFFER_NUM == 1) begin
                base_index <= 0;
                read_base  <= baseaddr;
            end
            else if ( BUFFER_NUM == 2) begin
                base_index[0] <= ~base_index[0];
                if (base_index[0]) begin
                    read_base <= baseaddr;
                end
                else begin
                    read_base <= read_base + MAX_WIDTH * MAX_HEIGHT * COLOR_PLANE * BYTEPERSYMBOL;  
                end
            end
            else begin
                if ( base_index == BUFFER_NUM-1 ) begin
                    if ( writer_base_index != 0 ) begin
                        base_index <= 0;
                        read_base  <= baseaddr;
                    end
                end
                else if ( (base_index + 1) != writer_base_index ) begin
                    base_index <= base_index + 1;
                    read_base  <= read_base + MAX_WIDTH * MAX_HEIGHT * COLOR_PLANE * BYTEPERSYMBOL;  
                end
            end
        end
        else if (~go_stable) begin
            read_base  <= baseaddr;
            base_index <= 0;
        end
    end

    assign reader_base_index = base_index;


    //��go�źŲ�����֡����д�߳�ͬ����ready_go�źš�
    always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
        ready_go <= 0;
    end
    else begin 
        ready_go <= go_stable;
    end

    //��ready_go�źŲ���control_go��
    //ready_go�ź���Чʱ��control_go��ÿ��ȡ��1�����ݺ��Զ���Ч�Զ�ȡ��һ�����ݡ�
    always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
        sync_go <= 0;
        delay_go <= 0;
    end
    else begin
        sync_go <= ready_go;
        delay_go <= sync_go;
    end
    

    always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
        sync_done <= 1;
        delay_done <= 1;
        delay1_done <= 1;
        delay2_done <= 1;
    end
    else begin
        sync_done <= control_done;
        delay_done <= sync_done;
        delay1_done <= delay_done;
        delay2_done <= delay1_done;
    end

    assign control_go = (((sync_go ^ delay_go) & sync_go) && sync_done && (height_counter == 1 )) || 
                        (((delay1_done ^ delay2_done) & sync_done) && (go_stable || (height_counter > 1)));


    //�����м���
    always @ (posedge axis_aclk or negedge reset_n)
    if (!reset_n) begin
        width_counter <= 1;
    end
    else begin
        if (control_done) begin
            width_counter <= 1; 
        end
        else if (user_read_buffer == 1) begin 
            width_counter <= width_counter + 1;
        end
    end

    //�����м���
    always @ (posedge clk or negedge reset_n)
    if(!reset_n) begin
        height_counter <= 1;
    end
    else if ( (delay_done ^ sync_done) & sync_done ) begin
        if ( height_counter == sync_height  ) begin
            height_counter <= 1;
        end
        else begin
            height_counter <= height_counter + 1;
        end
    end


    always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
        sync_mode <= 0;
        sync_width <= 0;
        sync_height <= 0;
    end
    else begin
        if ( (((sync_go ^ ready_go) & ready_go)      && (height_counter == 1)) ||
            (((delay_done ^ sync_done) & sync_done) && (height_counter == sync_height)) ) begin
            sync_mode <= mode;
            sync_width <= width;
            sync_height <= height;
        end
    end
    


    //�����м���������һ�еķ��ʵ�ַ��  
    always @ (posedge clk or negedge reset_n)
    if(!reset_n) begin
        read_offset <= 0;
    end
    else begin
        if ( (delay1_done ^ delay_done) & delay_done ) begin
            if (sync_mode == 3) begin //���е��������
                if ( height_counter == 1 ) begin 
                    read_offset <= (sync_height-1) * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;            
                end
                else if (height_counter == sync_height/2+1) begin
                    read_offset <= (sync_height-2) * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL; 
                end
                else begin
                    read_offset <= read_offset - 2 * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;     
                end
            end
            else if (sync_mode == 2) begin //������� �����ż�У����������
                if (height_counter == 1 ) begin
                    read_offset <= MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;
                end
                else if ( height_counter == sync_height/2 + 1) begin 
                    read_offset <= 0;
                end
                else begin
                    read_offset <= read_offset + 2 * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL; 
                end
            end
            else if (sync_mode == 1) begin //���е������
                    if ( height_counter == 1 ) begin
                        read_offset <= (sync_height-1) * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;
                    end
                    else begin
                        read_offset <= read_offset - MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;
                    end
            end
            else begin              //�������
                if ( height_counter == 1  ) begin
                    read_offset <= 0;
                end
                else begin
                    read_offset <= read_offset + MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;
                end
            end
        end
        else if( ((sync_go ^ ready_go) & ready_go) && sync_done && (height_counter == 1 ) ) begin
            if (mode == 3) begin
                read_offset <= (sync_height-1) * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;            
            end
            else if (mode == 2) begin
                read_offset <= 0;
            end
            else if (mode == 1) begin
                read_offset <= (sync_height-1) * MAX_WIDTH * COLOR_PLANE * BYTEPERSYMBOL;
            end
            else begin
                read_offset <= 0;
            end
        end
    end


    assign control_read_base = read_offset + read_base;
    assign control_read_length = sync_width * COLOR_PLANE * BYTEPERSYMBOL;


    // ���������
    reg [15 : 0] height_cnt;
    reg [15 : 0] width_cnt;
    always @(posedge axis_aclk or negedge reset_n)
    if (!reset_n) begin
        height_cnt <= 0;
        width_cnt <= 0;
    end
    else begin
        if (m_axis_tvalid & m_axis_tready) begin
            if (width_cnt >= sync_width - 1) begin
                width_cnt <= 0;

                if (height_cnt >= sync_height - 1) begin
                    height_cnt <= 0;
                end
                else begin
                    height_cnt <= height_cnt + 1;
                end

            end
            else begin
                height_cnt <= height_cnt;
                width_cnt <= width_cnt + 1;
            end
        end
        else begin
            height_cnt <= height_cnt;
            width_cnt <= width_cnt;
        end

        
    end

    assign user_read_buffer = m_axis_tready & user_data_available;
    assign m_axis_tvalid = user_data_available;
    assign m_axis_tdata = user_buffer_output_data;
    assign m_axis_tuser = (width_cnt == 0) & (height_cnt == 0) & user_data_available;
    assign m_axis_tlast = (width_cnt == sync_width * COLOR_PLANE-1) & user_data_available;


    burst_read_master_nuc a_burst_read_master(
        .clk (clk),
        .reset_n (reset_n),
        .sync_width(sync_width),
        .control_read_base (control_read_base),
        .control_read_length (control_read_length),
        .control_go (control_go),
        .control_done (control_done),
        .user_read_clk(axis_aclk),
        .user_read_buffer (user_read_buffer),
        .user_buffer_data (user_buffer_output_data),
        .user_data_available (user_data_available),

        .m_axi_araddr       (m_axi_araddr ),
        .m_axi_arburst      (m_axi_arburst),
        .m_axi_arcache      (m_axi_arcache),
        .m_axi_arlen        (m_axi_arlen  ),
        .m_axi_arprot       (m_axi_arprot ),
        .m_axi_arready      (m_axi_arready),
        .m_axi_arsize       (m_axi_arsize ),
        .m_axi_aruser       (m_axi_aruser ),
        .m_axi_arvalid      (m_axi_arvalid),
        .m_axi_rdata        (m_axi_rdata  ),
        .m_axi_rlast        (m_axi_rlast  ),
        .m_axi_rready       (m_axi_rready ),
        .m_axi_rresp        (m_axi_rresp  ),
        .m_axi_rvalid       (m_axi_rvalid )
    );
    defparam a_burst_read_master.DATAWIDTH_MM = DATAWIDTH_MM;
    defparam a_burst_read_master.DATAWIDTH_ST = DATAWIDTH_ST;
    defparam a_burst_read_master.MAXBURSTCOUNT = MAXBURSTCOUNT;
    defparam a_burst_read_master.BURSTCOUNTWIDTH = BURSTCOUNTWIDTH;
    defparam a_burst_read_master.BYTEENABLEWIDTH = BYTEENABLEWIDTH;
    defparam a_burst_read_master.ADDRESSWIDTH = ADDRESSWIDTH;
    defparam a_burst_read_master.FIFODEPTH = FIFODEPTH;
    defparam a_burst_read_master.FIFODEPTH_LOG2_MM = FIFODEPTH_LOG2_MM;
    defparam a_burst_read_master.FIFODEPTH_LOG2_ST = FIFODEPTH_LOG2_ST;

endmodule
