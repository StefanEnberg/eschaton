module Google
  
  # Represents a google map[http://code.google.com/apis/maps/documentation/reference.html#GMap2]
  class Map < MapObject
    attr_reader :center, :zoom
    
    Control_types = [:small_map, :large_map, :small_zoom, 
                     :scale, 
                     :map_type, :menu_map_type, :hierarchical_map_type,
                     :overview_map]
    
    # Options: 
    # :center::   => Optional. Centers the map at this location, see center=.
    # :controls:: => Optional. Which controls will be added to the map, see Control_types for valid controls.
    # :zoom::     => Optional. The zoom level of the map defaulted to 6, see zoom=.
    def initialize(options = {})
      options.default! :var => 'map', :zoom => 6
      
      super
            
      options.assert_valid_keys :controls, :center, :zoom

      if self.create_var?
        script << "#{self.var} = new GMap2(document.getElementById('#{self.var}'));" 
    
        self.center = options[:center] if options[:center]
        self.zoom = options[:zoom] if options[:zoom]        
        self.add_control(options[:controls]) if options[:controls]
      end
    end
    
    # Centers the map at the given +location+ which can be a Location or whatever Location#new supports.
    #
    # Examples:
    #  map.center = {:latitude => -34, :longitude => 18.5}
    #
    #  map.center = Google::Location.new(:latitude => -34, :longitude => 18.5)
    def center=(location)
      @center = location.to_location

      self.set_center(self.center)
    end
    
    # Sets the zoom level of the map.
    def zoom=(zoom)
      @zoom = zoom

      self.set_zoom(self.zoom)
    end

    # Adds a control or controls to the map
    #   add_control :small_zoom, :map_type
    def add_control(*controls)
      controls.flatten.each do |control|
        script << "#{self.var}.addControl(new #{control.to_google_control_class}());"
      end
    end

    # Adds a single +marker+ to the map which can be a Marker or whatever Marker#new supports.     
    def add_marker(marker)
      add_markers marker
    end
    
    # Adds markers to the map. Each marker in +markers+ can be a Marker or whatever Marker#new supports.
    def add_markers(*markers)
      marker_objects = markers.collect{|marker_or_options| marker_or_options.to_marker}
      
      marker_objects.each do |marker|
        self << "#{self.var}.addOverlay(#{marker.var});"
      end
      
      if marker_objects.size == 1
        marker_objects.first
      else
        marker_objects
      end
    end
    
    # Clears all overlays(info windows, markers, lines etc) from the map.
    def clear
      self.clear_overlays
    end

    # Attaches the given block to the "click" event of the map.
    # This will only run if the map is clicked, not an info window or overlay.
    #
    # :yields [:script, :overlay, :location]
    def click    
      self.listen_to :event => :click, :with => [:overlay, :location] do |*args|
        script = args.first               
        script << "if(location){"

        yield *args

        script << "}"
      end
    end

    # Opens a information window on the map at the given +location+. Either a +url+ or +content+ option can be supplied 
    # to place within the info window.
    #
    # :location::         => Required. A Location, whatever Location#new supports or :center which indicates where the info window must be placed on the map.
    # :url::              => Optional. URL is generated by rails #url_for. Supports standard url arguments and javascript variable interpolation.
    # :include_location:: => Optional. Indicates if latitude and longitude parameters of +location+ should be sent through with the +url+, defaulted to +false+.
    # :content::          => Optional. The html content that will be placed inside the info window. 
    def open_info_window(options)
      options.assert_valid_keys :location, :url, :include_location, :content
      options.default! :include_location => false
      
      location = options[:location]
      location = if location == :center
                   "#{self.var}.getCenter()"
                 else
                   location.to_location
                 end

      if options[:url]
        if options[:include_location]
          if location.is_a?(Symbol)
            options[:url][:latitude] = "##{location}.lat()"
            options[:url][:longitude] = "##{location}.lng()"
          else
            options[:url][:latitude] = location.latitude
            options[:url][:longitude] = location.longitude
          end
        end

        self.script.get(options[:url]) do |data|
          self << "#{self.var}.openInfoWindow(#{location}, #{data});"
        end
      else
        self << "#{self.var}.openInfoWindow(#{location}, #{options[:content].to_js});"
      end
    end

  end
end
