require File.dirname(__FILE__) + '/base'

# Here's how to set up an XY Scatter Chart
#
# g = Gruff::Scatter.new(800)
# g.data(:apples, [1,2,3,4], [4,3,2,1])
# g.data('oranges', [5,7,8], [4,1,7])
# g.write('test/output/scatter.png')
# 
#
class Gruff::Scatter < Gruff::Base

  # Maximum X Value. The value will get overwritten by the max in the
  # datasets.  
  attr_accessor :maximum_x_value
  
  # Minimum X Value. The value will get overwritten by the min in the 
  # datasets.  
  attr_accessor :minimum_x_value
  
  # The number of vertical lines shown for reference
  attr_accessor :marker_x_count

  attr_accessor :description
  
  #~ # Draw a dashed horizontal line at the given y value
  #~ attr_accessor :baseline_y_value
	
  #~ # Color of the horizontal baseline
  #~ attr_accessor :baseline_y_color
  
  #~ # Draw a dashed horizontal line at the given y value
  #~ attr_accessor :baseline_x_value
	
  #~ # Color of the horizontal baseline
  #~ attr_accessor :baseline_x_color
  
  
  # Gruff::Scatter takes the same parameters as the Gruff::Line graph
  #
  # ==== Example
  #
  # g = Gruff::Scatter.new
  #
  def initialize(*args)
    super(*args)
    
    @maximum_x_value = @minimum_x_value = nil
    @baseline_x_color = @baseline_y_color = 'red'
    @baseline_x_value = @baseline_y_value = nil
    @marker_x_count = nil
    @slope_ranges = []
    @description = nil
  end
  
  def draw
    calculate_spread
    @sort = false
    
    # TODO Need to get x-axis labels working. Current behavior will be to not allow.
    @labels = {}
    
    # Translate our values so that we can use the base methods for drawing
    # the standard chart stuff
    @column_count = @x_spread

    super 
    return unless @has_data

    # Check to see if more than one datapoint was given. NaN can result otherwise.  
    @x_increment = (@column_count > 1) ? (@graph_width / (@column_count - 1).to_f) : @graph_width

    @norm_data.each do |data_row|      
      prev_x = prev_y = nil

      data_row[DATA_VALUES_INDEX].each_with_index do |data_point, index|
        x_value = data_row[DATA_VALUES_X_INDEX][index]
        next if data_point.nil? || x_value.nil? 

        new_x = getXCoord(x_value, @graph_width, @graph_left)
        new_y = @graph_top + (@graph_height - data_point * @graph_height)

        # Reset each time to avoid thin-line errors
        @d = @d.stroke data_row[DATA_COLOR_INDEX]
        @d = @d.fill data_row[DATA_COLOR_INDEX]
        @d = @d.stroke_opacity 1.0
        @d = @d.stroke_width clip_value_if_greater_than(@columns / (@norm_data.first[1].size * 4), 5.0)

        circle_radius = clip_value_if_greater_than(@columns / (@norm_data.first[1].size * 2.5), 5.0)
        @d = @d.circle(new_x, new_y, new_x - circle_radius, new_y)

        prev_x = new_x
        prev_y = new_y
      end
    end

    draw_slope_ranges(@d, @graph_top)
    draw_description

    @d.draw(@base_image)
  end
  
  # The first parameter is the name of the dataset.  The next two are the
  # x and y axis data points contain in their own array in that respective
  # order.  The final parameter is the color.
  #
  # Can be called multiple times with different datasets for a multi-valued
  # graph.
  #
  # If the color argument is nil, the next color from the default theme will
  # be used.
  #
  # NOTE: If you want to use a preset theme, you must set it before calling
  # data().
  #
  # ==== Parameters
  # name:: String or Symbol containing the name of the dataset.
  # x_data_points:: An Array of of x-axis data points. 
  # y_data_points:: An Array of of y-axis data points. 
  # color:: The hex string for the color of the dataset.  Defaults to nil.
  #
  # ==== Exceptions
  # Data points contain nil values::
  #   This error will get raised if either the x or y axis data points array
  #   contains a <tt>nil</tt> value.  The graph will not make an assumption
  #   as how to graph <tt>nil</tt>
  # x_data_points is empty::
  #   This error is raised when the array for the x-axis points are empty
  # y_data_points is empty::
  #   This error is raised when the array for the y-axis points are empty
  # x_data_points.length != y_data_points.length::
  #   Error means that the x and y axis point arrays do not match in length
  #
  # ==== Examples
  # g = Gruff::Scatter.new
  # g.data(:apples, [1,2,3], [3,2,1])
  # g.data('oranges', [1,1,1], [2,3,4])
  # g.data('bitter_melon', [3,5,6], [6,7,8], '#000000')
  #
  def data(name, x_data_points=[], y_data_points=[], color=nil)
    
    raise ArgumentError, "Data Points contain nil Value!" if x_data_points.include?(nil) || y_data_points.include?(nil)
    raise ArgumentError, "x_data_points is empty!" if x_data_points.empty?
    raise ArgumentError, "y_data_points is empty!" if y_data_points.empty?
    raise ArgumentError, "x_data_points.length != y_data_points.length!" if x_data_points.length != y_data_points.length
    
    # Call the existing data routine for the y axis data
    super(name, y_data_points, color)
    
    #append the x data to the last entry that was just added in the @data member
    lastElem = @data.length()-1
    @data[lastElem] << x_data_points

    @maximum_x_value ||= x_data_points.first
    @minimum_x_value ||= x_data_points.first
    
    @maximum_x_value = x_data_points.max > @maximum_x_value ?
                        x_data_points.max : @maximum_x_value
    @minimum_x_value = x_data_points.min < @minimum_x_value ?
                        x_data_points.min : @minimum_x_value
  end

  def slope_range(color, from, to)
    @slope_ranges << { :color => color, :arg_from => from, :arg_to => to }
  end

  # Draws a title on the graph.
  def draw_description
    return if @hide_description and @description

    @d = @d.push

    @d.font = @font if @font
    @d.stroke('transparent')
    @d.pointsize = scale_fontsize(@description_font_size)
    @d.gravity = CenterGravity

    y = @top_margin +
      (@hide_title  ? 0.0 : @title_caps_height  + @title_margin ) +
      (@hide_legend ? 0.0 : @legend_caps_height + @legend_margin)

    @description.each_with_index do |e, i|
      @d.fill = e[:color] || @font_color
      @d = @d.annotate_scaled( @base_image,
                       @raw_columns, 1.0,
                       (i - 1) * 200.0, y,
                       e[:text], @scale)
    end

    @d = @d.pop
  end
  
protected
  
  def calculate_spread #:nodoc:
    super
    @x_spread = @maximum_x_value.to_f - @minimum_x_value.to_f
    @x_spread = @x_spread > 0 ? @x_spread : 1
  end
  
  def normalize(force=@xy_normalize)
    if @norm_data.nil? || force 
      @norm_data = []
      return unless @has_data
      
      @data.each do |data_row|
        norm_data_points = [data_row[DATA_LABEL_INDEX]]
        norm_data_points << data_row[DATA_VALUES_INDEX].map do |r|  
                                (r.to_f - @minimum_value.to_f) / @spread
                            end
        norm_data_points << data_row[DATA_COLOR_INDEX]
        norm_data_points << data_row[DATA_VALUES_X_INDEX].map do |r|  
                                (r.to_f - @minimum_x_value.to_f) / @x_spread 
                            end
        @norm_data << norm_data_points
      end
    end
    #~ @norm_y_baseline = (@baseline_y_value.to_f / @maximum_value.to_f) if @baseline_y_value
    #~ @norm_x_baseline = (@baseline_x_value.to_f / @maximum_x_value.to_f) if @baseline_x_value
  end
  
  def draw_line_markers
    # do all of the stuff for the horizontal lines on the y-axis
    super
    return if @hide_line_markers
    
    @d = @d.stroke_antialias false

    if @x_axis_increment.nil?
      # TODO Do the same for larger numbers...100, 75, 50, 25
      if @marker_x_count.nil?
        (3..7).each do |lines|
          if @x_spread % lines == 0.0
            @marker_x_count = lines
            break
          end
        end
        @marker_x_count ||= 4
      end
      @x_increment = (@x_spread > 0) ? significant(@x_spread / @marker_x_count) : 1
    else
      # TODO Make this work for negative values
      @maximum_x_value = [@maximum_value.ceil, @x_axis_increment].max
      @minimum_x_value = @minimum_x_value.floor
      calculate_spread
      normalize(true)
      
      @marker_count = (@x_spread / @x_axis_increment).to_i
      @x_increment = @x_axis_increment
    end
    @increment_x_scaled = @graph_width.to_f / (@x_spread / @x_increment)

    # Draw vertical line markers and annotate with numbers
    (0..@marker_x_count).each do |index|
      x = @graph_left + @graph_width - index.to_f * @increment_x_scaled

      unless @hide_line_numbers
        marker_label = index * @x_increment + @minimum_x_value.to_f
        y_offset = @graph_top - LABEL_MARGIN * 4
        x_offset = getXCoord(index.to_f, @increment_x_scaled, @graph_left)

        @d.fill = @font_color
        @d.font = @font if @font
        @d.stroke('transparent')
        @d.pointsize = scale_fontsize(@marker_font_size)
        @d.gravity = NorthGravity
        
        @d = @d.annotate_scaled(@base_image, 
                          1.0, 1.0, 
                          x_offset, y_offset, 
                          label(marker_label), @scale)
      end
    end
    
    @d = @d.stroke_antialias true
  end
  
private
  
  def getXCoord(x_data_point, width, offset) #:nodoc:
    return(x_data_point * width + offset)
  end

  def draw_slope_ranges(d, level)
    d = d.push
    d.stroke("#000000").stroke_width(1)
    @slope_ranges.each do |e|
      d = d.push
      d.fill(e[:color]).opacity(0.4)
      y_from = e[:arg_from] * @x_spread * (@graph_height /  @spread.to_f)
      y_to = e[:arg_to] * @x_spread * (@graph_height /  @spread.to_f)
      d.polygon(@graph_left, level, @graph_left + @graph_width, level + y_from, @graph_left + @graph_width, level + y_to)
      d.pop
    end
    d = d.pop
  end

end # end Gruff::Scatter
