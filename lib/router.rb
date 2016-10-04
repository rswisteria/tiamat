module Router
  class Place
    def initialize(name, lat, lon)
      @name = name
      @lat = lat
      @lon = lon
    end

    def name
      @name
    end

    def ==(other)
      if other.is_a?(Router::Place)
        name == other.name
      else
        false
      end
    end

    def to_s
      @name
    end

    def lat
      @lat
    end

    def lon
      @lon
    end

    def distance(other)
      y1 = lat * Math::PI / 180
      x1 = lon * Math::PI / 180
      y2 = other.lat * Math::PI / 180
      x2 = other.lon *  Math::PI / 180
      earth_r = 6378140
      
      deg = Math::sin(y1) * Math::sin(y2) + Math::cos(y1) * Math::cos(y2) * Math::cos(x2 - x1)
      distance = earth_r * (Math::atan(-deg / Math::sqrt(-deg * deg + 1)) + Math::PI / 2) / 1000
    end
  end

  class Edge
    def initialize(place_from, place_to, distance)
      @place_from = place_from
      @place_to = place_to
      @distance = distance
    end

    def place_from
      @place_from
    end

    def place_to
      @place_to
    end

    def reverse!
      tmp = @place_from
      @place_from = @place_to
      @place_to = tmp
      self
    end

    def distance
      @distance
    end

    def ==(other)
      if other.is_a?(Router::Edge)
        ((place_from == other.place_from && place_to == other.place_to) || 
         (place_from == other.place_to && place_to == other.place_from) &&
         distance == other.distance)
      else
        false
      end
    end

    def <=>(other)
      if other.is_a?(Router::Edge)
        distance <=> other.distance
      else
        nil
      end
    end

    def to_s
      "(#{place_from.to_s}-#{place_to.to_s}, [#{distance}])"
    end
  end

  class Route
    def initialize(edges_from_start, start_from)
      @start_from = start_from
      @edges_from_start = edges_from_start.map do |edge|
        if edge.place_from != start_from && edge.place_to == start_from
          edge.reverse!
        end
        edge
      end
      @routes = []
      @places = []
    end

    def first
      @routes.first
    end

    def last
      @routes.last
    end

    def places
      @places
    end

    def routes
      @routes
    end
    
    def connect(other)
      if other.is_a?(Router::Edge)
        if @routes.length == 0
          @routes << @edges_from_start.find { |edge| edge.place_to == other.place_from }
          @routes << other
          @routes << @edges_from_start.find { |edge| edge.place_to == other.place_to }
          @routes[1].reverse!

          @places << other.place_from
          @places << other.place_to
          return 1
        else
          if @places.include?(other.place_from) && @places.include?(other.place_to)
            # nop
            return -1
          elsif !@places.include?(other.place_from) && !@places.include?(other.place_to)
            # nop (but can create other route)
            return 0
          elsif @routes.first.place_to == other.place_from
            @routes[0] = @edges_from_start.find { |edge| edge.place_to == other.place_to }
            @routes.insert(1, other.reverse!)
            @places << other.place_from
            return 1
          elsif @routes.first.place_to == other.place_to
            @routes[0] = @edges_from_start.find { |edge| edge.place_to == other.place_from }
            @routes.insert(1, other)
            @places << other.place_from
            return 1
          elsif @routes.last.place_from == other.place_from
            @routes[@routes.length - 1] = other
            @routes << @edges_from_start.find { |edge| edge.place_to == other.place_to }.reverse!
            @places << other.place_to
            return 1
          elsif @routes.last.place_from == other.place_to
            @routes[@routes.length - 1] = other.reverse!
            @routes << @edges_from_start.find { |edge| edge.place_to == other.place_to }.reverse!
            @places << other.place_to
            return 1
          else
            # nop
            return -1
          end
        end
      elsif other.is_a?(Router::Route)
        if first.place_to == other.last.place_from
          other_dup = other.routes.clone
          other_dup.pop
          @routes.shift
          @routes = other_dup + @routes
          return 1
        elsif last.place_from == other.first.place_to
          other_dup = other.routes.clone
          other_dup.shift
          @routes.pop
          @routes = @routes + other_dup
          return 1
        else
          return -1
        end

      end
    end

    def to_s
      @routes.map { |edge| edge.to_s }.join(", ")
    end
    
    class << self
      def do_calc_route(graph, start_from)
        distance_array = graph
        edges_from_start = graph.select { |edge| edge.place_from == start_from || edge.place_to == start_from }
        saving_array = calc_saving_array(distance_array, start_from)
        calc_routes = calc_route(saving_array, start_from, edges_from_start)
        calc_routes.map(&:to_s)
      end

      def calc_saving_array(distance_array, start_from)
        places = []
        distance_from_start = []
        distance_array.each do |edge|
          places << edge.place_from if (!places.include?(edge.place_from) && edge.place_from != start_from)
          places << edge.place_to   if (!places.include?(edge.place_to)   && edge.place_to   != start_from)
        end

        retval = []

        places.each do |from|
          places.each do |to|
            if retval.find { |edge| (edge.place_from == from && edge.place_to == to) || (edge.place_from == to && edge.place_to == from) }.nil? && from != to
              a = distance_array.find { |edge| edge.place_from == start_from && edge.place_to == from }
              b = distance_array.find { |edge| edge.place_from == start_from && edge.place_to == to }
              c = distance_array.find { |edge| (edge.place_from == from       && edge.place_to == to) || (edge.place_from == to       && edge.place_to == from) }
              retval << Edge.new(from, to, a.distance + b.distance - c.distance)
            end
          end
        end
        
        retval
      end

      def calc_route(saving_array, start_from, edges_from_start)
        routes = [Route.new(edges_from_start, start_from)]
        sorted_saving_array = saving_array.sort.reverse
        sorted_saving_array.each do |edge|
          routes.each do |route|
            retval = route.connect(edge)
            if retval == 0
              if route == routes.last
                routes << Route.new(edges_from_start, start_from)
              end
            else
              break
            end
          end
        end

        routes
      end
    end
  end

  class Sample
    class << self
      def get_places
        [
         Place.new('xtone', 35.651131, 139.709535),
         Place.new('Ebisu Station', 35.646468, 139.7097391),
         Place.new('Daikanyama Station', 35.6480923, 139.7031489),
         Place.new('Liquid Room', 35.6490884, 139.7105505),
         Place.new('Higashi Health Plaza', 35.6503005, 139.7095849)
        ]
      end

      def get_distance
        get_places.combination(2).map do |a, b|
          Edge.new(a, b, a.distance(b))
        end
      end

      def calc
        Route.do_calc_route(get_distance, get_places()[0])
      end
    end
  end
end
