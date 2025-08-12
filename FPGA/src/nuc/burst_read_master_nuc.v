module burst_read_master_nuc (
        clk,
        reset_n,
        // control inputs and outputs
        sync_width,
        control_read_base,
        control_read_length,
        control_go,
        control_done,

        // user logic inputs and outputs
        user_read_clk,
        user_read_buffer,
        user_buffer_data,
        user_data_available,

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
        m_axi_rvalid
    );

    parameter DATAWIDTH_MM = 64;       
    parameter DATAWIDTH_ST = 8;        
    parameter MAXBURSTCOUNT = 8;
    parameter BURSTCOUNTWIDTH = 4;
    parameter BYTEENABLEWIDTH = 8;
    parameter ADDRESSWIDTH = 32;
    parameter FIFODEPTH = 64;          
    parameter FIFODEPTH_LOG2_MM = 6;   
    parameter FIFODEPTH_LOG2_ST = 9;   
  
    function integer clogb2 (input integer bit_depth);              
    begin                                                           
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
            bit_depth = bit_depth >> 1;                                 
    end                                                           
    endfunction                                                     

    localparam DATAWIDTH_LOG2_MM = clogb2(DATAWIDTH_MM-1);
    localparam DATAWIDTH_LOG2_ST = clogb2(DATAWIDTH_ST-1);
    localparam LSB_WIDTH  = DATAWIDTH_LOG2_MM - DATAWIDTH_LOG2_ST;
    localparam axi_axsize = clogb2(BYTEENABLEWIDTH-1);
    
    input                             clk;
    input                             reset_n;


    // control inputs and outputs
    input [15 : 0]                    sync_width;
    input [ADDRESSWIDTH-1:0]          control_read_base;
    input [ADDRESSWIDTH-1:0]          control_read_length;
    input                             control_go;
    output wire                       control_done;

    // user logic inputs and outputs
    input                             user_read_clk;
    input                             user_read_buffer;
    output wire [DATAWIDTH_ST-1:0]    user_buffer_data;
    output wire                       user_data_available;

    // AXI master inputs and outputs
    output  wire    [ADDRESSWIDTH-1:0]      m_axi_araddr;
    output  wire    [1:0]                   m_axi_arburst;
    output  wire    [3:0]                   m_axi_arcache;
    output  wire    [7:0]                   m_axi_arlen;
    output  wire    [2:0]                   m_axi_arprot;
    input   wire                            m_axi_arready;
    output  wire    [2:0]                   m_axi_arsize;
    output  wire    [3:0]                   m_axi_aruser;
    output  reg                             m_axi_arvalid;
    input   wire    [DATAWIDTH_MM-1:0]      m_axi_rdata;
    input   wire                            m_axi_rlast;
    output  wire                            m_axi_rready;
    input   wire    [1:0]                   m_axi_rresp;
    input   wire                            m_axi_rvalid;

    reg [15:0] cnt;
  
    // internal control signals
    wire                              fire;
    reg                               m_axi_rlast_r0;
    reg                               m_axi_rlast_r1;
    wire                              last_pulse;
    wire                              fifo_empty;
    reg [ADDRESSWIDTH-1:0]            address;
    reg [ADDRESSWIDTH-1:0]            length;

    wire                              increment_address;
    reg  [BURSTCOUNTWIDTH-1:0]        burst_count;
    wire [BURSTCOUNTWIDTH-1:0]        first_short_burst_count;
    wire                              first_short_burst_enable;
    wire [BURSTCOUNTWIDTH-1:0]        final_short_burst_count;
    wire                              final_short_burst_enable;
    wire [BURSTCOUNTWIDTH-1:0]        burst_boundary_word_address;

    wire                              too_many_reads_pending;
    // wire [FIFODEPTH_LOG2_MM-1:0]      fifo_used;
    wire [32-1:0]      fifo_used;

    wire                              rdfull;
    // wire [FIFODEPTH_LOG2_MM-1:0]      rdusedw;
    wire [32-1:0]      rdusedw;
    wire                              wrempty;
    wire                              wrfull; 
    wire [DATAWIDTH_MM-1:0]           rddata;
    wire                              rdreq;
    reg  [LSB_WIDTH:0]                symb_cnt;




    // reg [FIFODEPTH_LOG2_MM-1:0]         read_cnt;
    reg [32-1:0]         read_cnt;

    reg initial_flag;
    always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
        initial_flag <= 1;
    end
    else begin
        if (control_go) begin
            initial_flag <= 0;
        end
    end




    assign last_pulse	= (!m_axi_rlast_r1) & m_axi_rlast_r0;


    always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
        m_axi_rlast_r0 <= 0;
        m_axi_rlast_r1 <= 0;
    end
    else begin
        m_axi_rlast_r0 <= m_axi_rlast;
        m_axi_rlast_r1 <= m_axi_rlast_r0;
    end

    // master address logic 
    always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
        address <= 0;
    end
    else begin
        if (control_go == 1) begin
            address <= control_read_base;
        end
        else if (increment_address == 1) begin
            address <= address + (burst_count * BYTEENABLEWIDTH);  // always performing word size accesses, increment by the burst count presented
        end
    end

    // master length logic
    always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
        length <= 0;
    end
    else begin
        if (control_go == 1) begin
            length <= control_read_length;
        end
        else if (increment_address == 1) begin
            length <= length - (burst_count * BYTEENABLEWIDTH);  // always performing word size accesses, decrement by the burst count presented
        end
    end


    always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
        m_axi_arvalid <= 0;
        burst_count <= 0;
    end
    else begin
        if (m_axi_arvalid & m_axi_arready) begin
            m_axi_arvalid <= 1'b0;
        end
        else if ((too_many_reads_pending == 0) & (length != 0)) begin
            m_axi_arvalid <= 1'b1;
        end


        if(~m_axi_arvalid) begin
            burst_count <= (first_short_burst_enable == 1)? first_short_burst_count :  // this will get the transfer back on a burst boundary, 
                (final_short_burst_enable == 1)? final_short_burst_count : MAXBURSTCOUNT;
        end

    end


    always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
        read_cnt <= 0;
    end
    else begin
        if (increment_address) begin
            if (fire) begin
                read_cnt <= read_cnt + burst_count - 1;
            end
            else begin
                read_cnt <= read_cnt + burst_count;
            end
        end
        else begin
            if (fire) begin
                read_cnt <= read_cnt - 1;
            end
            else begin
                read_cnt <= read_cnt;
            end
        end
    end

    // assign control_done = (length == 0) & ( (cnt == sync_width) | initial_flag);
    assign control_done = (length == 0) & (read_cnt == 0);


    assign burst_boundary_word_address = ((address / BYTEENABLEWIDTH) & (MAXBURSTCOUNT - 1));
    assign first_short_burst_enable = (burst_boundary_word_address != 0);
    assign final_short_burst_enable = (length < (MAXBURSTCOUNT * BYTEENABLEWIDTH));

    assign first_short_burst_count = ((burst_boundary_word_address & 1'b1) == 1'b1)? 1 :  // if the burst boundary isn't a multiple of 2 then must post a burst of 1 to get to a multiple of 2 for the next burst
                                    (((MAXBURSTCOUNT - burst_boundary_word_address) < (length / BYTEENABLEWIDTH))?
                                    (MAXBURSTCOUNT - burst_boundary_word_address) : (length / BYTEENABLEWIDTH));
    assign final_short_burst_count = (length / BYTEENABLEWIDTH);

    assign increment_address = m_axi_arvalid & m_axi_arready;

    assign too_many_reads_pending = (read_cnt + fifo_used) >= (FIFODEPTH - MAXBURSTCOUNT*10);  // make sure there are fewer reads posted than room in the FIFO


    // axi controlled signals
    assign m_axi_araddr = address;
    assign m_axi_arburst = 2'b1;
    assign m_axi_arlen = burst_count - 1;
    assign m_axi_arsize = axi_axsize;


    assign m_axi_arcache = 4'b1111;
    assign m_axi_arprot = 3'b010;
    assign m_axi_aruser = 4'b0;

    assign m_axi_rready = (read_cnt > 0) & !last_pulse;
    assign fire = m_axi_rready & m_axi_rvalid;



    // read data feeding user logic 
    assign user_data_available = !fifo_empty;

    async_fifo async_fifo(
        
        .wr_clk_i           ( clk ),
        .rd_clk_i           ( user_read_clk ),
        .a_rst_i            ( ~reset_n ),

        .wr_en_i            ( fire ),
        .rd_en_i            ( rdreq ),

        .wdata              ( m_axi_rdata ),
        .rdata              ( rddata ),

        .full_o             ( wrfull ),
        .empty_o            ( fifo_empty ),
        
        .wr_datacount_o     ( fifo_used ),
        .rd_datacount_o     ( rdusedw ),
        .rst_busy           ( )
    );

    generate
        if (LSB_WIDTH == 0)  begin
            assign user_buffer_data = rddata;     
            assign rdreq = user_read_buffer;
            always @ (posedge user_read_clk or negedge reset_n) begin
                symb_cnt <= 0;
            end
        end
        else if(DATAWIDTH_MM > DATAWIDTH_ST) begin
            assign user_buffer_data = rddata[(DATAWIDTH_ST*symb_cnt[LSB_WIDTH-1:0])+:DATAWIDTH_ST]; 
            assign rdreq = !fifo_empty && user_read_buffer && (symb_cnt[LSB_WIDTH-1:0]==(2**LSB_WIDTH-1));
            
            always @ (posedge user_read_clk or negedge reset_n)
            if (!reset_n) begin
                symb_cnt <= 0;      
            end
            else begin
                if (!fifo_empty && user_read_buffer) begin
                    symb_cnt <= symb_cnt + 1'b1;
                end
            end

        end
    endgenerate




 
    // 由于dcfifo存在产生错误fifo_empty信号的问题
    // 对一行中已输出的像素个数进行计数，用以产生control_done信号
    // 如果fifo_empty信号无误
    // 则control_done的条件中 (cnt == sync_width) | initial_flag 可替换成 fifo_empty 
    always @ (posedge user_read_clk or negedge reset_n)
    if (!reset_n) begin
        cnt <= 0;
    end
    else begin
        if (control_go) begin
            cnt <= 0;
        end
        else if (user_read_buffer & user_data_available) begin
            cnt <= cnt + 1;
        end
        else begin
            cnt <= cnt;
        end
    end



endmodule
