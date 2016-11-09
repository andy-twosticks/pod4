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

      flds, vals = parse_hash(fldsValues)
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

      flds, vals = parse_hash(fldsValues)
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

      flds, vals = parse_hash(selection)

      [ "where " + flds.map {|f| %Q|#{f} = #{placeholder}| }.join(" and "),
        vals ]

    end


    ##
    # Return the name of the table quoted as for inclusion in SQL. Might include the name of the
    # schema, too, if you have set one.
    #
    # table() is mandatory for an Interface, and if we have a schema it will be schema().
    #
    def quoted_table
      defined?(schema) && schema ? %Q|"#{schema}"."#{table}"| : %Q|"#{table}"|
    end


    ##
    # Given a string which is supposedly the name of a column, return a string with the column name
    # quoted for inclusion to SQL.
    #
    # Defaults to SQL standard double quotes. Override if you want something else.
    #
    def quote_field(fld)
      raise ArgumentError, "bad field name" unless fld.kind_of?(String) || fld.kind_of?(Symbol)
      %Q|"#{fld}"|
    end


    ##
    # Given some value, quote it for inclusion in SQL.
    #
    # Tries to follow the generic SQL standard -- single quotes for strings, NULL for nil, etc.
    # Override it if you want something else.
    #
    # Note that this also turns "O'Claire" into "O''Claire", as required by SQL.
    #
    def quote(fld)

      case fld
        when Date, Time
          "'#{fld}'" 
        when String
          "'#{fld.gsub("'", "''")}'" 
        when Symbol
          "'#{fld.to_s.gsub("'", "''")}'" 
        when BigDecimal
          fld.to_f
        when nil
          'NULL'
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
    # Given an SQL string and an array of values as returned by sql_select() etc above -- combine
    # the two to make valid SQL.
    #
    # Note: Don't do this. Dreadful idea. 
    # If at all possible you should instead get the data source library to combine these two
    # things. This will protect you against SQL injection (or if not, the library has screwed up).
    #
    # Note also that in order for this to work, you must have not overridden placeholder().
    #
    def sql_subst(sql, array)
      raise ArgumentError, "bad SQL" unless sql.kind_of? String
      raise ArgumentError, "missing SQL" if sql.empty?

      begin
        args = Array(array).flatten.map(&:to_s)
      rescue 
        raise ArgumentError, "Bad values", $!
      end
      raise ArgumentError, "missing values" if args.any?{|a| a.empty? }

      case 
        when args.empty?    then sql
        when args.size == 1 then sql.gsub("%s", args.first) 
        else 
          raise ArgumentError, "wrong number of values" unless sql.scan("%s").count == args.count
          sql % args
      end
    end


    ##
    # Helper routine: given a hash, quote the keys as column names and the values as column values.
    # Return the hash as two arrays, to ensure the ordering is consistent.
    #
    def parse_hash(hash)
      flds = []; vals = []

      hash.each do|f, v|
        flds << quote_field(f.to_s)
        vals << quote(v)
      end

      [flds, vals]
    end

  end


end

