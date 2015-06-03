require 'colorize'

module Lambda
    class Lexer
        RULES = {
            # Regex for matching token  => token kind
            /'.'/                               => :char,
            /[+-]?[0-9]+[L]?/                   => :integer,
            /\/\*.*?\*\//                       => :comment,

            /\{/                                => :begin_block,
            /\}/                                => :end_block,
            /\(/                                => :lparen,
            /\)/                                => :rparen,

            /,/                                 => :special,
            /`/                                 => :special,
            /λ/                                 => :special,

            /\+/                                => :operator,
            /\//                                => :operator,
            /\-/                                => :operator,
            /\*/                                => :operator,
            /\./                                => :operator,
            /%/                                 => :operator,

            /&&/                                => :operator,
            /\|\|/                              => :operator,
            />=?/                               => :operator,
            /<=?/                               => :operator,

            /[_a-zA-Z][_0-9a-zA-Z]*/            => :identifier,

            # Note that the order of these matters! This lexer is lazy, so it will always match `=` over `==` unless we specify `==` first.
            /==/                                => :operator,
            /=/                                 => :special,
            /!=/                                => :operator
        }

        KEYWORDS = ["if", "elseif", "else", "lambda"]

        def initialize(source, file_name = "src")
            @source = source
            @scanner = StringScanner.new source
            @file_name = file_name
        end

        def next_token
            @scanner.skip(/\s+/)
            @scanner.skip(/\n+/)

            if @scanner.eos? then
                return Token.new :eof, nil, col_num(pos) + 1, 1, line_num
            end

            RULES.each do |matcher, kind|
                if content = @scanner.scan(matcher) then
                    if kind == :comment then
                        return next_token
                    end
                    if kind == :identifier && KEYWORDS.include?(content) then
                        kind = :keyword
                    end
                    pos = @scanner.pos
                    tok = Token.new kind, content, col_num(pos) - content.length + 1, content.length, line_num

                    return tok
                end
            end

            raise_lexing_error "Unexpected character '#{@scanner.getch}' while scanning.", @scanner.pos
        end

        def raise_lexing_error(msg, pos)
            header = "#{@file_name}##{line_num}: "
            str = "Error: #{msg}\n".red
            str << "#{@file_name}##{line_num - 1}: #{@source.lines[line_num - 2].chomp}\n".light_black if line_num > 1
            str << "#{header}#{(@source.lines[line_num - 1] || "").chomp}\n"
            str << (' ' * (col_num(@scanner.pos) + header.length - 1))
            str << '^' << "\n"
            str << "#{@file_name}##{line_num + 1}: #{@source.lines[line_num].chomp}\n".light_black if @source.lines[line_num]
            raise str
        end

        def line_num
            @source[0..@scanner.pos].count("\n") + 1
        end

        def pos
            @scanner.pos
        end

        def col_num(pos)
            len_before_this_line = @source[0..pos].lines[0..-2].map{|x| x.length}.reduce{|x, y| x + y} || 0
            pos - len_before_this_line
        end
    end
end
