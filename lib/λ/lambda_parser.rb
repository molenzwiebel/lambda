
module Lambda
    def parse(src, name = "unknown_file")
        Lambda.parse src, name
    end

    def self.parse(src, name = "unknown_file")
        parser = construct_parser src, name
        contents = []
        while node = parser.parse_expression
            contents << node
        end
        Body.from contents
    end

    def self.construct_parser(src, file_name = "src")
        Parser.new(src, file_name) do
            expr -> x { x.is_integer? } do
                Num.new consume.value.to_i
            end

            expr -> x { x.is_identifier? } do
                Ident.new consume.value
            end

            expr -> x { x.is_char? } do
                Num.new consume.value[1...-1].ord
            end

            expr -> x { x.is_keyword?("lambda") or x.is?("λ") } do
                next_token # Consume kw
                name = token.is_identifier? ? consume.value : nil
                LambdaDef.new name, parse_delimited { expect_and_consume(:identifier).value }, parse_expression
            end

            expr -> x { x.is_lparen? } do
                next_token
                expr = parse_expression
                expect_and_consume :rparen
                expr
            end

            expr -> x { x.is_keyword? "if" } do
                expect_next_and_consume :lparen
                cond = parse_expression
                expect_and_consume(:rparen)

                then_body = parse_expression
                else_body = nil

                elseifs = []
                while token.is_keyword? "else" or token.is_keyword? "elseif"
                    raise_error "Multiple else blocks in if statement", token if token.is_keyword? "else" and else_body
                    if consume.is_keyword? "else" then
                        else_body = parse_expression
                    else
                        expect_and_consume(:lparen)
                        elseif_cond = parse_expression
                        expect_and_consume(:rparen)

                        elseifs << [elseif_cond, parse_expression]
                    end
                end

                elseifs.reverse_each do |else_if|
                    else_body = If.new else_if.first, else_if.last, else_body
                end

                If.new cond, then_body, else_body
            end

            expr -> x { x.is_begin_block? } do
                next_token
                contents = []
                until token.is_end_block?
                    contents << parse_expression
                end
                next_token
                Body.from contents
            end

            infix 50, -> x { x.is_lparen? } do |left|
                Call.new left, parse_delimited { parse_expression }
            end

            infix 12, -> x { x.is_operator? "+" }, &create_binary_parser(12)
            infix 12, -> x { x.is_operator? "-" }, &create_binary_parser(12)
            infix 13, -> x { x.is_operator? "*" }, &create_binary_parser(13)
            infix 13, -> x { x.is_operator? "/" }, &create_binary_parser(13)
            infix 11, -> x { x.is_operator? "%" }, &create_binary_parser(11)

            infix 5, -> x { x.is_operator? "&&"  }, &create_binary_parser(5)
            infix 4, -> x { x.is_operator? "||"  }, &create_binary_parser(4)
            infix 10, -> x { x.is_operator? "<"  }, &create_binary_parser(10)
            infix 10, -> x { x.is_operator? "<=" }, &create_binary_parser(10)
            infix 10, -> x { x.is_operator? ">"  }, &create_binary_parser(10)
            infix 10, -> x { x.is_operator? ">=" }, &create_binary_parser(10)

            infix 9, -> x { x.is_operator? "==" }, &create_binary_parser(9)
            infix 9, -> x { x.is_operator? "!=" }, &create_binary_parser(9)

            infix 1, -> x { x.is? "=" }, &create_binary_parser(1, true)
        end
    end

    class Parser
        def create_binary_parser(prec, right_associative = false)
            return lambda do |left|
                op_tok = consume # Consume operator
                right = parse_expression right_associative ? prec - 1 : prec
                raise_error "Expected expression at right hand side of #{op_tok.value}", op_tok unless right
                Binary.new(left, op_tok.value, right)
            end
        end

        def parse_delimited(start_tok = "(", delim = ",", end_tok = ")")
            expect start_tok
            next_token # Consume start token

            ret = []
            until token.is? end_tok
                raise_error("Unexpected EOF", token) if token.is_eof?
                ret << yield

                cor = token.is?(delim) || token.is?(end_tok)
                raise_error "Expected '#{delim}' or '#{end_tok}' in delimited list, received '#{token.value}'", token unless cor
                next_token if token.is? delim
            end
            next_token # Consume end token

            ret
        end
    end
end
