require File.dirname(__FILE__) + '/base'
 
class Gruff::GroupedBar < Gruff::Base
 
    # Spacing factor applied between bars
    attr_accessor :bar_spacing
     
    # Draws a bar graph, but multiple sets are stacked on top of each other.
    def draw
      super
      return unless @has_data
     
      @d = @d.stroke_opacity 0.0
      @d = @d.stroke_antialias false
       
      # Setup the BarConversion Object
      conversion = Gruff::BarConversion.new()
      conversion.graph_height = @graph_height
      conversion.graph_top = @graph_top
     
      # Set up the right mode [1,2,3] see BarConversion for further explanation
      if @minimum_value >= 0 then
        # all bars go from zero to positiv
        conversion.mode = 1
      else
        # all bars go from 0 to negativ
        if @maximum_value <= 0 then
          conversion.mode = 2
        else
          # bars either go from zero to negativ or to positiv
          conversion.mode = 3
          conversion.spread = @spread
          conversion.minimum_value = @minimum_value
          conversion.zero = -@minimum_value/@spread
        end
      end     
 
      # Setup spacing.
      @group_spacing  ||= 0.85 # space between the groups
      @group_width      = @graph_width / @column_count.to_f
      padding           = (@group_width * (1 - @group_spacing)) / 2
      bar_width         = @group_width * @group_spacing / @norm_data.length.to_f
             
      width = Array.new(@column_count, 0)
      puts @norm_data.inspect
      @norm_data.each_with_index do |data_row, row_index|      
        data_row[DATA_VALUES_INDEX].each_with_index do |data_point, point_index|
          @d = @d.fill data_row[DATA_COLOR_INDEX]
 
          # Calculate center based on bar_width and current row
          if row_index == 0
            label_center = @graph_left + (@group_width * point_index) + padding + (@group_width * @group_spacing / 2.0)
            draw_label(label_center, point_index)
          end
 
          # Use incremented x and scaled y
          left_x  = @graph_left + (@group_width * point_index) + width[point_index] + padding
          right_x = left_x + bar_width
          conv = []
          conversion.getLeftYRightYscaled( data_point, conv )
 
          # update the total width of the current grouped bar
          width[point_index] += bar_width + 1
 
          next if (data_point == 0)
           
          @d = @d.rectangle(left_x, conv[0], right_x, conv[1])
        end
         
      end
     
      @d.draw(@base_image)
      @d = @d.stroke_antialias true
    end
 
end