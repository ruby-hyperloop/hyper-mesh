module ReactiveRecord
  class Graph < BasicObject
    # A simple Graph implementation, tailored for ReactiveRecord purposes
    # with just the things really needed, kept simple and thus fast

    # Node is kept internal for later js inlining on the client once this works
    class Node < BasicObject
      attr_accessor :children
      attr_accessor :parent
      attr_accessor :value
      attr_reader :key
      attr_reader :name
      
      def initialize(key, name, params = nil, parent = nil)
        @name = name
        @params = params
        @parent = parent
        @children = {}
        @key = key
      end

      def self.calculate_key(name, params = nil)
        "##{name}#_##{params}#"
      end

      def <<(child)
        merge(child)
      end

      def has_children?
        @children.size == 0
      end

      def is_leaf?
        @children.size == 0
      end

      def is_root?
        @parent.nil?
      end

      def merge!(child)
        if @children.has_key?(child.key)
          @children[child.key].children.each (child.children)    
        else
          @children[child.key] = child
        end
      end

      # vector: [[method, [param, param], [method, []]]
      def merge_vector!(vector)
        node_name = vector[0][0]
        node_params = vector[0][1]
        node_key = Node.calculate_key(node_name, node_params)
        @children[node_key] = Node.new(node_key, node_name, node_params, self) unless @children.has_key?(node_key)
        @children[node_key].merge_vector(vector[1..-1]) if vector[1]
      end
    end
    #### end Node ####

    attr_reader :root_nodes

    def initialize(root_name = nil, *tail)
      @root_nodes = { root_name: Node.new(root_name, root_name).merge_vector!(tail) }
    end

    def [](root, *tail)
      get(args)
    end

    def empty?
      @root_nodes == 0
    end

    def has_nodes?
      @root_nodes.size > 0
    end

    def merge!(graph)
      @root_nodes[root_name] = Node.new(root_nome, root_name) unless @root_nodes.has_key?(root_name)
      @root_nodes[root_name].merge_vector(vector) if vector
    end

    def merge_vector!(*vector)
    end
    
    def get(root, *tail)
    end
  end
end