// Lightweight synthesizable OSD for 640x480 RGB video.
//
// Layers:
//   1. Semi-transparent ANLOGIC logo panel.
//   2. Running HH:MM:SS timestamp.
//   3. Scrolling "FPGA HDMI MULTIMEDIA" caption.
//
// The panels use 4-bit alpha blending and the glyphs come from a compact
// 5x7 combinational font ROM, so no external memory initialization file is
// required.
module video_osd_overlay #(
    parameter integer PIXEL_CLK_HZ = 25_000_000
)(
    input             clk,
    input             rst,
    input             hs,
    input             vs,
    input             de,
    input      [23:0] rgb_in,
    output reg [23:0] rgb_out
);

reg [9:0] x;
reg [9:0] y;
reg       de_d;
reg       vs_d;

reg [24:0] second_count;
reg [4:0]  hours;
reg [5:0]  minutes;
reg [5:0]  seconds;

reg        scroll_frame_div;
reg [9:0]  scroll_pos;

reg [7:0]  glyph_char;
reg [4:0]  glyph_row_bits;
reg [4:0]  glyph_index;
reg [3:0]  glyph_col;
reg [3:0]  glyph_row;
reg [10:0] ticker_sum;
reg [9:0]  ticker_rel;

wire frame_tick;
assign frame_tick = vs & ~vs_d;

function [7:0] decimal_ascii;
    input [3:0] digit;
    begin
        decimal_ascii = 8'd48 + digit;
    end
endfunction

function [7:0] logo_char;
    input [4:0] index;
    begin
        case (index)
            4'd0: logo_char = "A";
            4'd1: logo_char = "N";
            4'd2: logo_char = "L";
            4'd3: logo_char = "O";
            4'd4: logo_char = "G";
            4'd5: logo_char = "I";
            4'd6: logo_char = "C";
            default: logo_char = " ";
        endcase
    end
endfunction

function [7:0] time_char;
    input [4:0] index;
    begin
        case (index)
            4'd0:  time_char = "T";
            4'd1:  time_char = "I";
            4'd2:  time_char = "M";
            4'd3:  time_char = "E";
            4'd4:  time_char = " ";
            4'd5:  time_char = decimal_ascii(hours / 10);
            4'd6:  time_char = decimal_ascii(hours % 10);
            4'd7:  time_char = ":";
            4'd8:  time_char = decimal_ascii(minutes / 10);
            4'd9:  time_char = decimal_ascii(minutes % 10);
            4'd10: time_char = ":";
            4'd11: time_char = decimal_ascii(seconds / 10);
            4'd12: time_char = decimal_ascii(seconds % 10);
            default: time_char = " ";
        endcase
    end
endfunction

function [7:0] ticker_char;
    input [4:0] index;
    begin
        case (index)
            5'd0:  ticker_char = "F";
            5'd1:  ticker_char = "P";
            5'd2:  ticker_char = "G";
            5'd3:  ticker_char = "A";
            5'd4:  ticker_char = " ";
            5'd5:  ticker_char = "H";
            5'd6:  ticker_char = "D";
            5'd7:  ticker_char = "M";
            5'd8:  ticker_char = "I";
            5'd9:  ticker_char = " ";
            5'd10: ticker_char = "M";
            5'd11: ticker_char = "U";
            5'd12: ticker_char = "L";
            5'd13: ticker_char = "T";
            5'd14: ticker_char = "I";
            5'd15: ticker_char = "M";
            5'd16: ticker_char = "E";
            5'd17: ticker_char = "D";
            5'd18: ticker_char = "I";
            5'd19: ticker_char = "A";
            default: ticker_char = " ";
        endcase
    end
endfunction

function [4:0] font5x7;
    input [7:0] ch;
    input [2:0] row;
    begin
        font5x7 = 5'b00000;
        case (ch)
            "A": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b11111; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b10001; default: font5x7=5'b00000; endcase
            "C": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10000;
                3: font5x7=5'b10000; 4: font5x7=5'b10000; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "D": case (row)
                0: font5x7=5'b11110; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b10001; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b11110; default: font5x7=5'b00000; endcase
            "E": case (row)
                0: font5x7=5'b11111; 1: font5x7=5'b10000; 2: font5x7=5'b10000;
                3: font5x7=5'b11110; 4: font5x7=5'b10000; 5: font5x7=5'b10000;
                6: font5x7=5'b11111; default: font5x7=5'b00000; endcase
            "F": case (row)
                0: font5x7=5'b11111; 1: font5x7=5'b10000; 2: font5x7=5'b10000;
                3: font5x7=5'b11110; 4: font5x7=5'b10000; 5: font5x7=5'b10000;
                6: font5x7=5'b10000; default: font5x7=5'b00000; endcase
            "G": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10000;
                3: font5x7=5'b10111; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "H": case (row)
                0: font5x7=5'b10001; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b11111; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b10001; default: font5x7=5'b00000; endcase
            "I": case (row)
                0: font5x7=5'b11111; 1: font5x7=5'b00100; 2: font5x7=5'b00100;
                3: font5x7=5'b00100; 4: font5x7=5'b00100; 5: font5x7=5'b00100;
                6: font5x7=5'b11111; default: font5x7=5'b00000; endcase
            "L": case (row)
                0: font5x7=5'b10000; 1: font5x7=5'b10000; 2: font5x7=5'b10000;
                3: font5x7=5'b10000; 4: font5x7=5'b10000; 5: font5x7=5'b10000;
                6: font5x7=5'b11111; default: font5x7=5'b00000; endcase
            "M": case (row)
                0: font5x7=5'b10001; 1: font5x7=5'b11011; 2: font5x7=5'b10101;
                3: font5x7=5'b10101; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b10001; default: font5x7=5'b00000; endcase
            "N": case (row)
                0: font5x7=5'b10001; 1: font5x7=5'b11001; 2: font5x7=5'b10101;
                3: font5x7=5'b10011; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b10001; default: font5x7=5'b00000; endcase
            "O": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b10001; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "P": case (row)
                0: font5x7=5'b11110; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b11110; 4: font5x7=5'b10000; 5: font5x7=5'b10000;
                6: font5x7=5'b10000; default: font5x7=5'b00000; endcase
            "T": case (row)
                0: font5x7=5'b11111; 1: font5x7=5'b00100; 2: font5x7=5'b00100;
                3: font5x7=5'b00100; 4: font5x7=5'b00100; 5: font5x7=5'b00100;
                6: font5x7=5'b00100; default: font5x7=5'b00000; endcase
            "U": case (row)
                0: font5x7=5'b10001; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b10001; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "0": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10011;
                3: font5x7=5'b10101; 4: font5x7=5'b11001; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "1": case (row)
                0: font5x7=5'b00100; 1: font5x7=5'b01100; 2: font5x7=5'b00100;
                3: font5x7=5'b00100; 4: font5x7=5'b00100; 5: font5x7=5'b00100;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "2": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b00001;
                3: font5x7=5'b00010; 4: font5x7=5'b00100; 5: font5x7=5'b01000;
                6: font5x7=5'b11111; default: font5x7=5'b00000; endcase
            "3": case (row)
                0: font5x7=5'b11110; 1: font5x7=5'b00001; 2: font5x7=5'b00001;
                3: font5x7=5'b01110; 4: font5x7=5'b00001; 5: font5x7=5'b00001;
                6: font5x7=5'b11110; default: font5x7=5'b00000; endcase
            "4": case (row)
                0: font5x7=5'b00010; 1: font5x7=5'b00110; 2: font5x7=5'b01010;
                3: font5x7=5'b10010; 4: font5x7=5'b11111; 5: font5x7=5'b00010;
                6: font5x7=5'b00010; default: font5x7=5'b00000; endcase
            "5": case (row)
                0: font5x7=5'b11111; 1: font5x7=5'b10000; 2: font5x7=5'b10000;
                3: font5x7=5'b11110; 4: font5x7=5'b00001; 5: font5x7=5'b00001;
                6: font5x7=5'b11110; default: font5x7=5'b00000; endcase
            "6": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10000; 2: font5x7=5'b10000;
                3: font5x7=5'b11110; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "7": case (row)
                0: font5x7=5'b11111; 1: font5x7=5'b00001; 2: font5x7=5'b00010;
                3: font5x7=5'b00100; 4: font5x7=5'b01000; 5: font5x7=5'b01000;
                6: font5x7=5'b01000; default: font5x7=5'b00000; endcase
            "8": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b01110; 4: font5x7=5'b10001; 5: font5x7=5'b10001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            "9": case (row)
                0: font5x7=5'b01110; 1: font5x7=5'b10001; 2: font5x7=5'b10001;
                3: font5x7=5'b01111; 4: font5x7=5'b00001; 5: font5x7=5'b00001;
                6: font5x7=5'b01110; default: font5x7=5'b00000; endcase
            ":": case (row)
                1: font5x7=5'b00100; 2: font5x7=5'b00100;
                4: font5x7=5'b00100; 5: font5x7=5'b00100;
                default: font5x7=5'b00000; endcase
            default: font5x7 = 5'b00000;
        endcase
    end
endfunction

function [7:0] alpha_mix_channel;
    input [7:0] background;
    input [7:0] foreground;
    input [4:0] alpha;
    reg [12:0] mixed;
    begin
        mixed = background * (5'd16 - alpha) + foreground * alpha;
        alpha_mix_channel = mixed[11:4];
    end
endfunction

function [23:0] alpha_mix_rgb;
    input [23:0] background;
    input [23:0] foreground;
    input [4:0] alpha;
    begin
        alpha_mix_rgb = {
            alpha_mix_channel(background[23:16], foreground[23:16], alpha),
            alpha_mix_channel(background[15:8],  foreground[15:8],  alpha),
            alpha_mix_channel(background[7:0],   foreground[7:0],   alpha)
        };
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x    <= 10'd0;
        y    <= 10'd0;
        de_d <= 1'b0;
        vs_d <= 1'b0;
    end else begin
        de_d <= de;
        vs_d <= vs;

        if (de)
            x <= x + 10'd1;
        else
            x <= 10'd0;

        if (!vs)
            y <= 10'd0;
        else if (de_d && !de)
            y <= y + 10'd1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        second_count <= 25'd0;
        hours        <= 5'd0;
        minutes      <= 6'd0;
        seconds      <= 6'd0;
    end else if (second_count >= PIXEL_CLK_HZ - 1) begin
        second_count <= 25'd0;
        if (seconds == 6'd59) begin
            seconds <= 6'd0;
            if (minutes == 6'd59) begin
                minutes <= 6'd0;
                if (hours == 5'd23)
                    hours <= 5'd0;
                else
                    hours <= hours + 5'd1;
            end else begin
                minutes <= minutes + 6'd1;
            end
        end else begin
            seconds <= seconds + 6'd1;
        end
    end else begin
        second_count <= second_count + 25'd1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        scroll_frame_div <= 1'b0;
        scroll_pos       <= 10'd0;
    end else if (frame_tick) begin
        scroll_frame_div <= ~scroll_frame_div;
        if (scroll_frame_div) begin
            if (scroll_pos >= 10'd880)
                scroll_pos <= 10'd0;
            else
                scroll_pos <= scroll_pos + 10'd1;
        end
    end
end

always @* begin
    rgb_out        = de ? rgb_in : 24'h000000;
    glyph_char     = " ";
    glyph_row_bits = 5'b00000;
    glyph_index    = 5'd0;
    glyph_col      = 4'd0;
    glyph_row      = 4'd0;
    ticker_sum     = 11'd0;
    ticker_rel     = 10'd0;

    if (de) begin
        // Top-left logo panel, 12/16 alpha.
        if ((x >= 10'd18) && (x < 10'd174) && (y >= 10'd14) && (y < 10'd50))
            rgb_out = alpha_mix_rgb(rgb_out, 24'h075AA8, 5'd12);

        if ((x >= 10'd30) && (x < 10'd156) && (y >= 10'd22) && (y < 10'd43)) begin
            glyph_index    = (x - 10'd30) / 18;
            glyph_col      = ((x - 10'd30) % 18) / 3;
            glyph_row      = (y - 10'd22) / 3;
            glyph_char     = logo_char(glyph_index);
            glyph_row_bits = font5x7(glyph_char, glyph_row[2:0]);
            if ((glyph_col < 5) && glyph_row_bits[4-glyph_col])
                rgb_out = 24'hFFFFFF;
        end

        // Top-right clock panel, 10/16 alpha.
        if ((x >= 10'd420) && (x < 10'd622) && (y >= 10'd14) && (y < 10'd50))
            rgb_out = alpha_mix_rgb(rgb_out, 24'h101820, 5'd10);

        if ((x >= 10'd432) && (x < 10'd588) && (y >= 10'd25) && (y < 10'd39)) begin
            glyph_index    = (x - 10'd432) / 12;
            glyph_col      = ((x - 10'd432) % 12) / 2;
            glyph_row      = (y - 10'd25) / 2;
            glyph_char     = time_char(glyph_index);
            glyph_row_bits = font5x7(glyph_char, glyph_row[2:0]);
            if ((glyph_col < 5) && glyph_row_bits[4-glyph_col])
                rgb_out = 24'hFFE66D;
        end

        // Bottom caption strip and scrolling text.
        if ((y >= 10'd430) && (y < 10'd464))
            rgb_out = alpha_mix_rgb(rgb_out, 24'h071A2B, 5'd11);

        ticker_sum = {1'b0, x} + {1'b0, scroll_pos};
        if ((y >= 10'd440) && (y < 10'd454) &&
            (ticker_sum >= 11'd640) && (ticker_sum < 11'd880)) begin
            ticker_rel     = ticker_sum - 11'd640;
            glyph_index    = ticker_rel / 12;
            glyph_col      = (ticker_rel % 12) / 2;
            glyph_row      = (y - 10'd440) / 2;
            glyph_char     = ticker_char(glyph_index);
            glyph_row_bits = font5x7(glyph_char, glyph_row[2:0]);
            if ((glyph_col < 5) && glyph_row_bits[4-glyph_col])
                rgb_out = 24'h52E3FF;
        end
    end
end

endmodule
