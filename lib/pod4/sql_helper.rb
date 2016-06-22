module Pod4


  ##
  # A mixin to help interfaces that need to generate SQL
  #
  module SQLHelper

    def sql_select(fldsValues, selection)
      flds = fldsValues ? sql_fields(fldsValues) : ["*"]

      %Q|select #{flds.join ','}
                   from #{quoted_table}
                   #{sql_where selection};|

    end


    def sql_insert(id_fld, fldsValues)
      flds = sql_fields(fldsValues)
      vals = placeholder * flds.count

      %Q|insert into #{quoted_table}
           ( #{flds.join ','} )
           values( #{vals.join ','} )
           returning #{quote_fld id_fld};| 

    end


    def sql_update(fldsValues, selection)
      sets = fldsValues.map {|k,_| %Q| #{quote_field k} = #{placeholder}| }

      %Q|update #{quoted_table}
           set #{sets.join ','}
           #{sql_where selection};|
      
    end


    def sql_delete(selection)
      %Q|delete from #{quoted_table} #{sql_where selection};|
    end


    def sql_where(selection)
      return "" if (selection.nil? || selection == {})
      selection.map {|k,_| %Q|#{quote_field k} = #{placeholder}| }.join(" and ")
    end


    def sql_fields(hash)
      hash.keys.map{|f| quote_field f.to_s }
    end


    def quoted_table
      defined?(schema) ? %Q|"#{schema}"."#{table}"| : %Q|"#{table}"|
    end


    def quote_field(fld)
      %Q|"#{fld}"|
    end


    def placeholder
      "%s"
    end

  end


end

