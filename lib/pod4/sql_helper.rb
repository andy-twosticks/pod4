module Pod4


  ##
  # A mixin to help interfaces that need to generate SQL
  #
  module SQLHelper

    private

    def sql_select(fields, selection)
      flds = fields ? fields.map{|f| quote_field f} : ["*"]

      wsql, wvals = sql_where(selection)

      sql = %Q|select #{flds.join ','}
                 from #{quoted_table}
                 #{wsql};|

      [sql, wvals]
    end


    def sql_insert(id_fld, fldsValues)
      flds, vals = parse_hash(fldsValues)
      ph = Array(placeholder).flatten * flds.count

      sql = %Q|insert into #{quoted_table}
                 ( #{flds.join ','} )
                 values( #{ph.join ','} )
                 returning #{quote_field id_fld};| 

      [sql, vals]
    end


    def sql_update(fldsValues, selection)
      flds, vals = parse_hash(fldsValues)
      sets = flds.map {|f| %Q| #{f} = #{placeholder}| }

      wsql, wvals = sql_where(selection)

      sql = %Q|update #{quoted_table}
                 set #{sets.join ','}
                 #{wsql};|
                 
      [sql, vals + wvals]
    end


    def sql_delete(selection)
      wsql, wval = sql_where(selection)
      [ %Q|delete from #{quoted_table} #{wsql};|, 
        wval ]
    end


    def sql_where(selection)
      return ["", []] if (selection.nil? || selection == {})

      flds, vals = parse_hash(selection)

      [ "where " + flds.map {|f| %Q|#{f} = #{placeholder}| }.join(" and "),
        vals ]

    end


    def quoted_table
      defined?(schema) && schema ? %Q|"#{schema}"."#{table}"| : %Q|"#{table}"|
    end


    def quote_field(fld)
      %Q|"#{fld}"|
    end


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
    

    def placeholder
      "%s"
    end


    def sql_subst(sql, array)
      args = Array(array).flatten.map(&:to_s)

      case 
        when args.empty?    then sql
        when args.size == 1 then sql.gsub("%s", args.first) 
        else sql % args
      end
    end


    private


    def parse_hash(hash)
      hash.map{|k,v| [quote_field(k.to_s), quote(v)] }
    end

  end


end

