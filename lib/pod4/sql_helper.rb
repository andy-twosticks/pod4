module Pod4


  ##
  # A mixin to help interfaces that need to generate SQL
  #
  # Most of these methods return two things: an sql string with %s where each value should be; and
  # an array of values to insert.
  #
  # You can override placeholder() to change %s to something else. You can override quote() to
  # change how values are quoted and quote_fld() to change how column names are quoted. Of course
  # the SQL here won't be suitable for all data source libraries even then, but, it gives us some
  # common ground to start with.
  #
  # You can call sql_subst() to turn the SQL and the values array into actual SQL -- but don't do
  # that; you should call the parameterised query routines for the data source library instead.
  #
  module SQLHelper
    
   
    ##
    # Return the name of the table quoted as for inclusion in SQL. Might include the name of the
    # schema, too, if you have set one.
    #
    # table() is mandatory for an Interface, and if we have a schema it will be schema().
    #
    def quoted_table
      defined?(schema) && schema ? %Q|"#{schema}"."#{table}"| : %Q|"#{table}"|
    end


    private


    ##
    # Given a list of fields and a selection hash, return an SQL string and an array of values 
    # for an SQL SELECT.
    #
    def sql_select(fields, selection)
      flds = fields ? Array(fields).flatten.map{|f| quote_field f} : ["*"]

      wsql, wvals = sql_where(selection)

      sql = %Q|select #{flds.join ','}
                 from #{quoted_table}
                 #{wsql};|

      [sql, wvals]
    end


    ##
    # Given a column:value hash, return an SQL string and an array of values for an SQL INSERT.
    #
    # Note that we get the table ID field from id_fld, which is mandatory for an Interface.
    #
    def sql_insert(fldsValues)
      raise ArgumentError, "Needs a field:value hash" if fldsValues.nil? || fldsValues.empty?

      flds, vals = parse_fldsvalues(fldsValues)
      ph = Array(placeholder).flatten * flds.count

      sql = %Q|insert into #{quoted_table}
                 ( #{flds.join ','} )
                 values( #{ph.join ','} )
                 returning #{quote_field id_fld};| 

      [sql, vals]
    end


    ##
    # Given a column:value hash and a selection hash, return an SQL string and an array of values 
    # for an SQL UPDATE.
    #
    def sql_update(fldsValues, selection)
      raise ArgumentError, "Needs a field:value hash" if fldsValues.nil? || fldsValues.empty?

      flds, vals = parse_fldsvalues(fldsValues)
      sets = flds.map {|f| %Q| #{f} = #{placeholder}| }

      wsql, wvals = sql_where(selection)

      sql = %Q|update #{quoted_table}
                 set #{sets.join ','}
                 #{wsql};|
                 
      [sql, vals + wvals]
    end


    ##
    # Given a selection hash, return an SQL string and an array of values for an SQL DELETE.
    #
    def sql_delete(selection)
      wsql, wval = sql_where(selection)
      [ %Q|delete from #{quoted_table} #{wsql};|, 
        wval ]
    end


    ##
    # Given a selection hash, return an SQL string and an array of values 
    # for an SQL where clause.
    #
    # This is used internally; you probably don't need it unless you are trying to override
    # sql_select(), sql_update() etc.
    #
    def sql_where(selection)
      return ["", []] if (selection.nil? || selection == {})

      flds, vals = parse_fldsvalues(selection)

      [ "where " + flds.map {|f| %Q|#{f} = #{placeholder}| }.join(" and "),
        vals ]

    end


    ##
    # Given a string which is supposedly the name of a column, return a string with the column name
    # quoted for inclusion to SQL.
    #
    # Defaults to SQL standard double quotes. If you want something else, pass the new quote
    # character as the optional second parameter, and/or override the method.
    #
    def quote_field(fld, qc=%q|"|)
      raise ArgumentError, "bad field name" unless fld.kind_of?(String) || fld.kind_of?(Symbol)
      %Q|#{qc}#{fld}#{qc}|
    end


    ##
    # Given some value, quote it for inclusion in SQL.
    #
    # Tries to follow the generic SQL standard -- single quotes for strings, NULL for nil, etc.
    # If you want something else, pass a different quote character as the second parameter, and/or 
    # override the method.
    #
    # Note that this also turns 'O'Claire' into 'O''Claire', as required by SQL.
    #
    def quote(fld, qc=%q|'|)

      case fld
        when Date, Time
          %Q|#{qc}#{fld}#{qc}|
        when String
          %Q|#{qc}#{fld.gsub("#{qc}", "#{qc}#{qc}")}#{qc}|
        when Symbol
          %Q|#{qc}#{fld.to_s.gsub("#{qc}", "#{qc}#{qc}")}#{qc}|
        when BigDecimal
          fld.to_f
        when nil
          "NULL"
        else 
          fld
      end

    end
    

    ##
    # Return the placeholder to use in place of values when we return SQL.  Defaults to the
    # Ruby-friendly %s. Override it if you want everything else.
    #
    def placeholder
      "%s"
    end


    ##
    # Given a string (SQL) with %s placeholders and one or more values -- substitute the values for
    # the placeholders.
    #
    #     sql_subst("foo %s bar %s", "$1", "$2") #-> "foo $1 bar $2"
    #     sql_subst("foo %s bar %s", "$$"]     ) #-> "foo $$ bar $$"
    #
    # You can use this to configure your SQL ready for the parameterised query routine that comes
    # with your data library. Note: this does not work if you redefine placeholder().
    #
    # You could also use it to turn a sql-with-placeholders string into valid SQL, by passing the
    # (quoted) values array that you got from sql_select, etc.:
    #
    #     sql, vals =  sql_select(nil, id => 4)
    #     validSQL = sql_subst( sql, *vals.map{|v| quote v} )
    #
    # Note: Don't do this. Dreadful idea. 
    # If at all possible you should instead get the data source library to combine these two
    # things. This will protect you against SQL injection (or if not, the library has screwed up).
    #
    def sql_subst(sql, *args)
      raise ArgumentError, "bad SQL"     unless sql.kind_of? String
      raise ArgumentError, "missing SQL" if sql.empty?

      vals = args.map(&:to_s)

      case 
        when vals.empty?    then sql
        when vals.size == 1 then sql.gsub("%s", vals.first) 
        else 
          raise ArgumentError, "wrong number of values" unless sql.scan("%s").count == vals.count
          sql % args
      end
    end


    ##
    # Helper routine: given a hash, quote the keys as column names and keep the values as they are
    # (since we don't know whether your parameterised query routine in your data source library
    # does that for you).
    #
    # Return the hash as two arrays, to ensure the ordering is consistent.
    #
    def parse_fldsvalues(hash)
      flds = []; vals = []

      hash.each do|f, v|
        flds << quote_field(f.to_s)
        vals << v
      end

      [flds, vals]
    end

  end


end

