
module Lambda
    class Parser
        def initialize(src, file = "src", &block)
            @source = src
            @file = file
            @lexer = Lexer.new src, file
            @current_token = @lexer.next_token

            @expression_parsers = {} #Predicate: Void -> Expression
            @infix_parsers      = {} #Predicate: [Precedence, Void -> Expression]

            instance_exec &block if block
        end

        # Gets the next token from the parser.
        def next_token
            @current_token = @lexer.next_token
        end

        # Returns which token we are currently looking at.
        def current_token
            @current_token
        end
        alias :token :current_token

        # "Consumes" the current token, returning it and advancing to the next token.
        def consume
            cur = @current_token
            next_token
            return cur
        end

        # Defines a new expression matcher. The first argument is a proc or lambda that
        # takes in a token and returns whether the parsing block should be executed. The
        # block argument is ran as the parser (using instance_exec) and should return the
        # parsed expression.
        def expr(matcher, &block)
            @expression_parsers[matcher] = block
        end

        # Defines an infix expression parser with the provided precedence. This method
        # is used for registering operators. The first argument is a proc or lambda that
        # takes in a token and returns whether the parsing block should be executed. The
        # block argument is ran as the parser (using instance_exec) with a single argument,
        # the left hand side of the infix. The parsing block is expected to return the parsed
        # expression.
        def infix(precedence, matcher, &block)
            @infix_parsers[matcher] = [precedence, block]
        end

        # Parses an expression, optionally providing the precedence. This method
        # keeps in mind the precedence as described at the top of this file.
        # Returns nil when there is no expression to be parsed.
        def parse_expression(precedence = 0)
            ret, line = nil, current_token.line_num
            @expression_parsers.each do |matcher, parser|
                next unless matcher.call(current_token) && ret.nil?

                left = instance_exec &parser
                while precedence < cur_token_precedence
                    _, contents = @infix_parsers.select{|key, val| key.call @current_token}.first
                    left = instance_exec left, &contents.last
                end
                ret = left
            end
            add_line_info(line, ret) if ret
            ret
        end

        # Checks if the current token is of the specified kind and value,
        # and raises an error when this is not the case.
        def expect(one, two = nil)
            tok = token
            check_eq tok, one, two
        end

        def expect_and_consume(one, two = nil)
            ret = expect one, two
            next_token
            return ret
        end

        # Checks if the next token is of the specified kind and value,
        # and raises an error when this is not the case.
        def expect_next(one, two = nil)
            tok = next_token
            check_eq tok, one, two
        end

        def expect_next_and_consume(one, two = nil)
            ret = expect_next one, two
            next_token
            return ret
        end

        # Helper method for expect and expect_next that compares a token
        # and composes an error message when they are not equal.
        def check_eq(tok, one, two)
            one_matches = one.is_a?(Symbol) ? tok.is_kind?(one) : tok.is?(one)
            two_matches = two ? two.is_a?(Symbol) ? tok.is_kind?(two) : tok.is?(two) : true
            return tok if one_matches and two_matches

            type = one.is_a?(Symbol) ? one : two.is_a?(Symbol) ? two : nil
            val = one.is_a?(String) ? one : two.is_a?(String) ? two : nil

            err_msg = "Expected token"
            err_msg << " of type #{type.to_s.upcase}" if type
            err_msg << " with value of '#{val.to_s}'" if val
            err_msg << ", received a #{tok.kind.upcase} with value '#{tok.value.to_s}'"
            raise_error err_msg, tok
        end

        # Creates and raises a neatly formatted error message that indicates
        # the location and surroundings of the error. Line, col and length
        # are used for the fancy indication of where the error lies and can
        # be easily gotten from a token (as seen in check_eq). You can also
        # pass in a token, in which case that token will be used for positioning.
        def raise_error(message, line, col = 0, length = 0)
            line, col, length = line.line_num, line.column, line.length if line.is_a? Token

            header = "#{@file}##{line}: "
            str = "Error: #{message}\n".red
            str << "#{@file}##{line - 1}: #{@source.lines[line - 2].chomp}\n".light_black if line > 1
            str << "#{header}#{(@source.lines[line - 1] || "").chomp}\n"
            str << (' ' * (col + header.length - 1))
            str << '^' << ('~' * (length - 1)) << "\n"
            str << "#{@file}##{line + 1}: #{@source.lines[line].chomp}\n".light_black if @source.lines[line]
            raise str
        end

        private
        # Helper method that finds the precedence for the current token, or 0 if the
        # current token is not a valid infix token.
        def cur_token_precedence
            filtered = @infix_parsers.select{|key, val| key.call @current_token}
            return 0 if filtered.size == 0
            _, contents = filtered.first
            contents[0]
        end

        def add_line_info(line, node)
            return if node.is_a?(Body)
            return unless node.is_a?(ASTNode) || node.is_a?(::Enumerable)

            if node.is_a?(::Enumerable) then
                node.each {|el| add_line_info(line, el)}
            else
                node.line = line
                node.filename = @file
                node.instance_variables.each do |var|
                    add_line_info(line, node.instance_variable_get(var))
                end
            end
        end
    end
end
