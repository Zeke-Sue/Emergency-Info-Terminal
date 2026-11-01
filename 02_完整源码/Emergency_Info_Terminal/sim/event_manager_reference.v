`timescale 1ns/1ps

module event_manager_reference #(
    parameter integer CANCEL_FRAMES=1786
)(
    input wire clk,input wire rst,input wire frame_tick,input wire [31:0] now_seconds,
    input wire cmd_valid,input wire [2:0] cmd_opcode,input wire [1:0] cmd_source,
    input wire [2:0] cmd_kind,input wire [15:0] cmd_event_id,
    input wire [7:0] cmd_sequence,input wire [2:0] cmd_level,
    input wire cmd_drill,input wire cmd_pending,input wire [2:0] cmd_region,
    input wire cmd_time_trusted,input wire [15:0] cmd_remaining_seconds,
    input wire sync_blocked_valid,input wire [7:0] sync_blocked_set,
    output wire cmd_ready,output reg result_valid,output reg [3:0] result_code,
    output reg primary_valid,output reg [1:0] primary_source,
    output reg [2:0] primary_kind,output reg [15:0] primary_event_id,
    output reg [7:0] primary_sequence,
    output reg [2:0] primary_level,output reg primary_drill,output reg primary_pending,
    output reg primary_time_trusted,output reg [15:0] primary_remaining_seconds,
    output reg [2:0] primary_region,output reg [3:0] active_count,
    output reg [4:0] tombstone_count,output reg [7:0] blocked_set,
    output wire cancel_notice,output reg full_urgent
);
    localparam S_IDLE=0,S_INIT=1,S_EVENT_SCAN=2,S_TOMB_SCAN=3,
               S_APPLY=4,S_WRITE_EVENT=5,S_CANCEL_WRITE=6,
               S_PRIMARY_SCAN=7,S_EXPIRE_WRITE=8,S_TOMB_SUM=9,
               S_TOMB_CLEAR=10,S_CLEAR=11;
    reg [3:0] state;
    reg [6:0] clear_index;
    reg [4:0] scan_index;
    reg [2:0] issue_word,read_word_d,write_word;
    reg read_issuing,read_valid;
    reg [127:0] scan_record;
    reg command_waiting,summary_waiting;

    reg [2:0] c_opcode,c_kind,c_level,c_region;
    reg [1:0] c_source;
    reg [15:0] c_event_id,c_remaining;
    reg [7:0] c_sequence;
    reg c_drill,c_pending,c_time_trusted;

    reg [3:0] existing_index,empty_index,evict_index;
    reg [2:0] evict_class;
    reg [31:0] evict_started;
    reg [127:0] existing_record;
    reg [4:0] tomb_match,tomb_empty,tomb_oldest;
    reg [31:0] tomb_oldest_until;

    reg candidate_valid;
    reg [7:0] candidate_score;
    reg [127:0] candidate_event;
    reg [3:0] active_acc;
    reg [4:0] tomb_acc;
    reg [7:0] blocked_acc;
    reg [7:0] manual_blocked;
    reg [11:0] cancel_frames_left;

    reg [3:0] write_event_index,write_tomb_index,clear_tomb_index;
    reg [127:0] write_event_record;
    reg [63:0] write_tomb_record;
    reg expire_last,tomb_clear_last;

    function [15:0] event_word;
        input [127:0] record;
        input [2:0] word_index;
        begin
            case(word_index)
                0:event_word=record[15:0];
                1:event_word=record[31:16];
                2:event_word=record[47:32];
                3:event_word=record[63:48];
                4:event_word=record[79:64];
                5:event_word=record[95:80];
                6:event_word=record[111:96];
                default:event_word=record[127:112];
            endcase
        end
    endfunction
    function [15:0] tomb_word;
        input [63:0] record;
        input [1:0] word_index;
        begin
            case(word_index)
                0:tomb_word=record[15:0];
                1:tomb_word=record[31:16];
                2:tomb_word=record[47:32];
                default:tomb_word=record[63:48];
            endcase
        end
    endfunction

    wire [15:0] mem_q;
    wire [127:0] scanned_event={mem_q,scan_record[111:0]};
    wire [63:0] scanned_tomb={mem_q,scan_record[47:0]};
    wire event_valid=scanned_event[0];
    wire [1:0] event_source=scanned_event[2:1];
    wire [2:0] event_kind=scanned_event[5:3];
    wire [15:0] event_id=scanned_event[21:6];
    wire [7:0] event_sequence=scanned_event[29:22];
    wire [2:0] event_level=scanned_event[32:30];
    wire event_drill=scanned_event[33];
    wire event_pending=scanned_event[34];
    wire [2:0] event_region=scanned_event[37:35];
    wire [15:0] event_remaining=scanned_event[54:39];
    wire [31:0] event_started=scanned_event[86:55];
    wire [31:0] event_expiry=scanned_event[118:87];
    wire event_expired=event_valid && event_expiry!=0 && event_expiry<=now_seconds;
    wire [2:0] current_evict_class=event_drill ? 3'd0 :
        (event_kind==2 ? 3'd1 : (event_level==4 ? 3'd2 :
        (event_level==3 ? 3'd3 : 3'd7)));
    wire current_protected=event_valid &&
        ((!event_drill && event_level<=2) || (event_kind==1 && event_pending));
    wire [7:0] current_primary_score=(event_drill ? 8'd64 : 8'd0)+
        {2'd0,event_level,3'd0}+{6'd0,event_source};
    wire current_primary_better=event_valid && !event_expired &&
        (!candidate_valid || current_primary_score<candidate_score);
    wire [127:0] final_candidate=current_primary_better ?
        scanned_event : candidate_event;
    wire [7:0] final_candidate_score=current_primary_better ?
        current_primary_score : candidate_score;
    wire final_candidate_valid=candidate_valid || current_primary_better;

    wire tomb_valid=scanned_tomb[0];
    wire [1:0] tomb_source=scanned_tomb[2:1];
    wire [15:0] tomb_id=scanned_tomb[18:3];
    wire [31:0] tomb_until=scanned_tomb[58:27];
    wire current_tomb_match=tomb_valid && tomb_source==c_source &&
        tomb_id==c_event_id && tomb_until>now_seconds;
    wire [4:0] selected_tomb_slot=tomb_empty<16 ? tomb_empty : tomb_oldest;

    wire [127:0] new_event_record={9'd0,now_seconds+c_remaining+32'd60,
        now_seconds,c_remaining,c_time_trusted,c_region,c_pending,c_drill,
        c_level,c_sequence,c_event_id,c_kind,c_source,1'b1};
    wire [63:0] existing_tomb_record={5'd0,
        now_seconds+(existing_record[5:3]==0 ? 32'd600 : 32'd1800),
        existing_record[29:22],c_event_id,c_source,1'b1};
    wire [63:0] expired_tomb_record={5'd0,
        now_seconds+(event_kind==0 ? 32'd600 : 32'd1800),
        event_sequence,event_id,event_source,1'b1};

    wire [6:0] event_read_base={scan_index[2:0],3'b000};
    wire [6:0] tomb_read_base=7'd64+{scan_index[3:0],2'b00};
    wire event_read_state=state==S_EVENT_SCAN || state==S_PRIMARY_SCAN;
    wire tomb_read_state=state==S_TOMB_SCAN || state==S_TOMB_SUM;
    wire [6:0] mem_ra=event_read_state ? event_read_base+issue_word :
        (tomb_read_state ? tomb_read_base+issue_word : 7'd0);
    wire clear_state=state==S_INIT || state==S_CLEAR;
    wire mem_we=clear_state || state==S_WRITE_EVENT ||
        state==S_CANCEL_WRITE || state==S_EXPIRE_WRITE || state==S_TOMB_CLEAR;
    wire [6:0] mem_wa=clear_state ? clear_index :
        (state==S_WRITE_EVENT ? {write_event_index[2:0],3'b000}+write_word :
        ((state==S_CANCEL_WRITE || state==S_EXPIRE_WRITE) ?
            (write_word==0 ? {write_event_index[2:0],3'b000} :
             7'd64+{write_tomb_index,2'b00}+(write_word-1'b1)) :
         7'd64+{clear_tomb_index,2'b00}));
    wire [15:0] mem_wd=clear_state || state==S_TOMB_CLEAR ? 16'd0 :
        (state==S_WRITE_EVENT ? event_word(write_event_record,write_word) :
        (write_word==0 ? 16'd0 : tomb_word(write_tomb_record,write_word-1'b1)));
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(7)) table_memory(
        .clk(clk),.we(mem_we),.wa(mem_wa),.ra(mem_ra),.d(mem_wd),.q(mem_q));

    assign cmd_ready=!command_waiting && state!=S_INIT && state!=S_CLEAR;
    assign cancel_notice=cancel_frames_left!=0;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=S_INIT;clear_index<=0;scan_index<=0;issue_word<=0;
            read_word_d<=0;write_word<=0;read_issuing<=0;read_valid<=0;
            scan_record<=0;command_waiting<=0;summary_waiting<=0;
            c_opcode<=0;c_kind<=0;c_level<=4;c_region<=0;c_source<=0;
            c_event_id<=0;c_remaining<=0;c_sequence<=0;
            c_drill<=0;c_pending<=0;c_time_trusted<=0;
            existing_index<=8;empty_index<=8;evict_index<=8;evict_class<=7;
            evict_started<=32'hffffffff;existing_record<=0;
            tomb_match<=16;tomb_empty<=16;tomb_oldest<=0;
            tomb_oldest_until<=32'hffffffff;
            candidate_valid<=0;candidate_score<=8'hff;candidate_event<=0;
            active_acc<=0;tomb_acc<=0;blocked_acc<=0;manual_blocked<=0;
            cancel_frames_left<=0;write_event_index<=0;write_tomb_index<=0;
            clear_tomb_index<=0;write_event_record<=0;write_tomb_record<=0;
            expire_last<=0;tomb_clear_last<=0;
            result_valid<=0;result_code<=0;full_urgent<=0;
            primary_valid<=0;primary_source<=0;primary_kind<=0;
            primary_event_id<=0;primary_sequence<=0;primary_level<=4;
            primary_drill<=0;primary_pending<=1;primary_time_trusted<=0;
            primary_remaining_seconds<=0;primary_region<=0;
            active_count<=0;tombstone_count<=0;blocked_set<=0;
        end else begin
            result_valid<=0;
            if(sync_blocked_valid) begin
                manual_blocked<=sync_blocked_set;
                blocked_set<=sync_blocked_set;
                summary_waiting<=1;
            end
            if(frame_tick) begin
                summary_waiting<=1;
                if(cancel_frames_left!=0) cancel_frames_left<=cancel_frames_left-1'b1;
            end
            if(cmd_valid && cmd_ready) begin
                command_waiting<=1;c_opcode<=cmd_opcode;c_source<=cmd_source;
                c_kind<=cmd_kind;c_event_id<=cmd_event_id;c_sequence<=cmd_sequence;
                c_level<=cmd_level;c_drill<=cmd_drill;c_pending<=cmd_pending;
                c_region<=cmd_region;c_time_trusted<=cmd_time_trusted;
                c_remaining<=cmd_remaining_seconds;
            end

            case(state)
                S_INIT:begin
                    if(clear_index==127) begin clear_index<=0;state<=S_IDLE;end
                    else clear_index<=clear_index+1'b1;
                end
                S_IDLE:begin
                    if(command_waiting) begin
                        scan_index<=0;issue_word<=0;read_issuing<=1;read_valid<=0;
                        scan_record<=0;existing_index<=8;empty_index<=8;
                        evict_index<=8;evict_class<=7;evict_started<=32'hffffffff;
                        state<=S_EVENT_SCAN;
                    end else if(summary_waiting) begin
                        summary_waiting<=0;scan_index<=0;issue_word<=0;
                        read_issuing<=1;read_valid<=0;scan_record<=0;
                        candidate_valid<=0;candidate_score<=8'hff;
                        active_acc<=0;blocked_acc<=manual_blocked;
                        state<=S_PRIMARY_SCAN;
                    end
                end
                S_EVENT_SCAN:begin
                    if(read_issuing) begin
                        read_word_d<=issue_word;read_valid<=1;
                        if(issue_word==7) read_issuing<=0;
                        else issue_word<=issue_word+1'b1;
                    end
                    if(read_valid) begin
                        case(read_word_d)
                            0:scan_record[15:0]<=mem_q;
                            1:scan_record[31:16]<=mem_q;
                            2:scan_record[47:32]<=mem_q;
                            3:scan_record[63:48]<=mem_q;
                            4:scan_record[79:64]<=mem_q;
                            5:scan_record[95:80]<=mem_q;
                            6:scan_record[111:96]<=mem_q;
                            default:begin
                                read_valid<=0;
                                if(event_valid && event_source==c_source && event_id==c_event_id) begin
                                    existing_index<={1'b0,scan_index[2:0]};
                                    existing_record<=scanned_event;
                                end
                                if(!event_valid && empty_index==8)
                                    empty_index<={1'b0,scan_index[2:0]};
                                if(event_valid && !current_protected &&
                                   (current_evict_class<evict_class ||
                                   (current_evict_class==evict_class && event_started<evict_started))) begin
                                    evict_index<={1'b0,scan_index[2:0]};
                                    evict_class<=current_evict_class;evict_started<=event_started;
                                end
                                if(scan_index==7) begin
                                    scan_index<=0;issue_word<=0;read_issuing<=1;
                                    scan_record<=0;tomb_match<=16;tomb_empty<=16;
                                    tomb_oldest<=0;tomb_oldest_until<=32'hffffffff;
                                    state<=S_TOMB_SCAN;
                                end else begin
                                    scan_index<=scan_index+1'b1;issue_word<=0;
                                    read_issuing<=1;scan_record<=0;
                                end
                            end
                        endcase
                    end
                end
                S_TOMB_SCAN:begin
                    if(read_issuing) begin
                        read_word_d<=issue_word;read_valid<=1;
                        if(issue_word==3) read_issuing<=0;
                        else issue_word<=issue_word+1'b1;
                    end
                    if(read_valid) begin
                        case(read_word_d)
                            0:scan_record[15:0]<=mem_q;
                            1:scan_record[31:16]<=mem_q;
                            2:scan_record[47:32]<=mem_q;
                            default:begin
                                read_valid<=0;
                                if(current_tomb_match) tomb_match<={1'b0,scan_index[3:0]};
                                if(!tomb_valid && tomb_empty==16)
                                    tomb_empty<={1'b0,scan_index[3:0]};
                                if(tomb_until<tomb_oldest_until) begin
                                    tomb_oldest<={1'b0,scan_index[3:0]};
                                    tomb_oldest_until<=tomb_until;
                                end
                                if(scan_index==15) state<=S_APPLY;
                                else begin
                                    scan_index<=scan_index+1'b1;issue_word<=0;
                                    read_issuing<=1;scan_record<=0;
                                end
                            end
                        endcase
                    end
                end
                S_APPLY:begin
                    command_waiting<=0;result_code<=0;
                    if(c_opcode==0) begin
                        if(tomb_match<16) begin
                            result_valid<=1;result_code<=3;state<=S_IDLE;
                        end else if(existing_index<8) begin
                            if(c_sequence>existing_record[29:22]) begin
                                write_event_index<=existing_index;write_event_record<=new_event_record;
                                write_word<=0;state<=S_WRITE_EVENT;
                            end else begin
                                result_valid<=1;
                                result_code<=c_sequence==existing_record[29:22] ? 1 : 2;
                                state<=S_IDLE;
                            end
                        end else if(empty_index<8 || evict_index<8) begin
                            write_event_index<=empty_index<8 ? empty_index : evict_index;
                            write_event_record<=new_event_record;write_word<=0;state<=S_WRITE_EVENT;
                        end else begin
                            result_valid<=1;result_code<=4;
                            if(!c_drill && c_level<4) full_urgent<=1;
                            state<=S_IDLE;
                        end
                    end else if(c_opcode==1 || c_opcode==2) begin
                        if(existing_index<8) begin
                            write_event_index<=existing_index;
                            write_tomb_index<=selected_tomb_slot[3:0];
                            write_tomb_record<=existing_tomb_record;
                            write_word<=0;state<=S_CANCEL_WRITE;
                            if(c_opcode==1 && primary_valid &&
                               primary_source==c_source && primary_event_id==c_event_id)
                                cancel_frames_left<=CANCEL_FRAMES;
                        end else begin
                            result_valid<=1;result_code<=5;state<=S_IDLE;
                        end
                    end else if(c_opcode==3) begin
                        manual_blocked[c_region]<=1;result_valid<=1;state<=S_IDLE;
                    end else if(c_opcode==4) begin
                        manual_blocked[c_region]<=0;result_valid<=1;state<=S_IDLE;
                    end else if(c_opcode==5) begin

                        full_urgent<=0;
                        manual_blocked<=0;cancel_frames_left<=0;primary_valid<=0;
                        active_count<=0;tombstone_count<=0;blocked_set<=0;
                        clear_index<=0;state<=S_CLEAR;
                    end else begin
                        result_valid<=1;result_code<=5;state<=S_IDLE;
                    end
                end
                S_WRITE_EVENT:begin

                    if(write_word==7) begin
                        result_valid<=1;result_code<=0;state<=S_IDLE;
                        cancel_frames_left<=0;
                    end
                    else write_word<=write_word+1'b1;
                end
                S_CANCEL_WRITE:begin
                    if(write_word==4) begin result_valid<=1;result_code<=0;state<=S_IDLE;end
                    else write_word<=write_word+1'b1;
                end
                S_CLEAR:begin
                    if(clear_index==127) begin
                        clear_index<=0;result_valid<=1;result_code<=0;state<=S_IDLE;
                    end else clear_index<=clear_index+1'b1;
                end
                S_PRIMARY_SCAN:begin
                    if(read_issuing) begin
                        read_word_d<=issue_word;read_valid<=1;
                        if(issue_word==7) read_issuing<=0;
                        else issue_word<=issue_word+1'b1;
                    end
                    if(read_valid) begin
                        case(read_word_d)
                            0:scan_record[15:0]<=mem_q;
                            1:scan_record[31:16]<=mem_q;
                            2:scan_record[47:32]<=mem_q;
                            3:scan_record[63:48]<=mem_q;
                            4:scan_record[79:64]<=mem_q;
                            5:scan_record[95:80]<=mem_q;
                            6:scan_record[111:96]<=mem_q;
                            default:begin
                                read_valid<=0;
                                if(event_expired) begin
                                    write_event_index<={1'b0,scan_index[2:0]};
                                    write_tomb_index<={1'b1,scan_index[2:0]};
                                    write_tomb_record<=expired_tomb_record;
                                    write_word<=0;expire_last<=scan_index==7;
                                    state<=S_EXPIRE_WRITE;
                                end else begin
                                    if(event_valid) begin
                                        active_acc<=active_acc+1'b1;
                                        if(event_kind==1) blocked_acc[event_region]<=1;
                                        if(current_primary_better) begin
                                            candidate_valid<=1;candidate_score<=current_primary_score;
                                            candidate_event<=scanned_event;
                                        end
                                    end
                                    if(scan_index==7) begin
                                        active_count<=active_acc+(event_valid ? 1'b1 : 1'b0);
                                        blocked_set<=event_valid && event_kind==1 ?
                                            blocked_acc|(8'b1<<event_region) : blocked_acc;
                                        if(final_candidate_valid &&
                                           (!cancel_notice || final_candidate_score<24)) begin
                                            primary_valid<=1;primary_source<=final_candidate[2:1];
                                            primary_kind<=final_candidate[5:3];
                                            primary_event_id<=final_candidate[21:6];
                                            primary_sequence<=final_candidate[29:22];
                                            primary_level<=final_candidate[32:30];
                                            primary_drill<=final_candidate[33];
                                            primary_pending<=final_candidate[34];
                                            primary_time_trusted<=final_candidate[38];
                                            primary_remaining_seconds<=final_candidate[54:39];
                                            primary_region<=final_candidate[37:35];

                                            if(final_candidate_score<24) cancel_frames_left<=0;
                                        end else primary_valid<=0;
                                        scan_index<=0;issue_word<=0;read_issuing<=1;
                                        scan_record<=0;tomb_acc<=0;state<=S_TOMB_SUM;
                                    end else begin
                                        scan_index<=scan_index+1'b1;issue_word<=0;
                                        read_issuing<=1;scan_record<=0;
                                    end
                                end
                            end
                        endcase
                    end
                end
                S_EXPIRE_WRITE:begin
                    if(write_word==4) begin
                        if(expire_last) begin
                            active_count<=active_acc;blocked_set<=blocked_acc;
                            if(candidate_valid && (!cancel_notice || candidate_score<24)) begin
                                primary_valid<=1;primary_source<=candidate_event[2:1];
                                primary_kind<=candidate_event[5:3];
                                primary_event_id<=candidate_event[21:6];
                                primary_sequence<=candidate_event[29:22];
                                primary_level<=candidate_event[32:30];
                                primary_drill<=candidate_event[33];
                                primary_pending<=candidate_event[34];
                                primary_time_trusted<=candidate_event[38];
                                primary_remaining_seconds<=candidate_event[54:39];
                                primary_region<=candidate_event[37:35];
                                if(candidate_score<24) cancel_frames_left<=0;
                            end else primary_valid<=0;
                            scan_index<=0;issue_word<=0;read_issuing<=1;
                            read_valid<=0;scan_record<=0;tomb_acc<=0;state<=S_TOMB_SUM;
                        end else begin
                            scan_index<=scan_index+1'b1;issue_word<=0;
                            read_issuing<=1;read_valid<=0;scan_record<=0;state<=S_PRIMARY_SCAN;
                        end
                    end else write_word<=write_word+1'b1;
                end
                S_TOMB_SUM:begin
                    if(read_issuing) begin
                        read_word_d<=issue_word;read_valid<=1;
                        if(issue_word==3) read_issuing<=0;
                        else issue_word<=issue_word+1'b1;
                    end
                    if(read_valid) begin
                        case(read_word_d)
                            0:scan_record[15:0]<=mem_q;
                            1:scan_record[31:16]<=mem_q;
                            2:scan_record[47:32]<=mem_q;
                            default:begin
                                read_valid<=0;
                                if(tomb_valid && tomb_until<=now_seconds) begin
                                    clear_tomb_index<=scan_index[3:0];
                                    tomb_clear_last<=scan_index==15;state<=S_TOMB_CLEAR;
                                end else begin
                                    if(tomb_valid) tomb_acc<=tomb_acc+1'b1;
                                    if(scan_index==15) begin
                                        tombstone_count<=tomb_acc+(tomb_valid ? 1'b1 : 1'b0);
                                        state<=S_IDLE;
                                    end else begin
                                        scan_index<=scan_index+1'b1;issue_word<=0;
                                        read_issuing<=1;scan_record<=0;
                                    end
                                end
                            end
                        endcase
                    end
                end
                S_TOMB_CLEAR:begin
                    if(tomb_clear_last) begin tombstone_count<=tomb_acc;state<=S_IDLE;end
                    else begin
                        scan_index<=scan_index+1'b1;issue_word<=0;
                        read_issuing<=1;read_valid<=0;scan_record<=0;state<=S_TOMB_SUM;
                    end
                end
                default:state<=S_INIT;
            endcase
        end
    end
endmodule
