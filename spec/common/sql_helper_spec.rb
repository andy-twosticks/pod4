require 'date'
require 'time'
require 'bigdecimal'
require 'pod4/sql_helper'


describe "SQLHelper" do

  let(:tester1_class) do
    Class.new do
      include SQLHelper

      def schema; "marco"; end
      def table;  "polo";  end
      def id_fld; "foo";   end
    end
  end

  let(:tester2_class) do
    Class.new do
      include SQLHelper

      def table; "polo"; end
    end
  end

  let(:tester1) {tester1_class.new}
  let(:tester2) {tester2_class.new}

    
  describe "quoted_table" do

    it "will be quoted with double quotes" do
      expect( tester2.quoted_table ).to eq %Q|"polo"|
    end

    it "will the schema plus the table if the schema is set" do
      expect( tester1.quoted_table ).to eq %Q|"marco"."polo"|
    end

  end


  describe "placeholder" do

    it "will be the ruby sprintf string subst string" do
      expect( tester1.send :placeholder ).to eq "%s"
    end

  end

    
  describe "quote_field" do

    it "will wrap the field in double quotes" do
      expect( tester1.send :quote_field, "thing" ).to eq %Q|"thing"|
    end

    it "will raise an error for a non-string" do
      expect{ tester1.send :quote_field, 12 }.to raise_error ArgumentError
      expect{ tester1.send :quote_field     }.to raise_error ArgumentError
    end

    it "will wrap the field in some other character if you pass that" do
      expect( tester1.send :quote_field, "thing", nil ).to eq %Q|thing|
      expect( tester1.send :quote_field, "thing", "x" ).to eq %Q|xthingx|
    end

  end

    
  describe "quote" do
    let(:datetime) { "2055-12-31 11:23:36+04"             }
    let(:dtmatch)  { /'2055.12.31[T ]11.23.36 ?\+04:?00'/ }

    it "returns a String wrapped in single quotes" do
      expect( tester1.send :quote, "foo" ).to eq %Q|'foo'|
    end

    it "turns a single quote into a doubled single quote" do
      expect( tester1.send :quote, "G'Kar" ).to eq %Q|'G''Kar'|
    end

    it "returns date wrapped in a single quote" do
      dt = Date.parse("2055-12-31")
      expect( tester1.send :quote, dt ).to eq %Q|'2055-12-31'|
    end

    it "returns datetime wrapped in a single quote" do
      dtm = DateTime.parse(datetime)
      expect( tester1.send :quote, dtm ).to match dtmatch
    end

    it "returns time wrapped in a single quote" do
      tm = Time.parse(datetime)
      expect( tester1.send :quote, tm ).to match dtmatch
    end

    it "returns a BigDecimal as a float" do
      bd = BigDecimal.new("14.98")
      expect( tester1.send :quote, bd ).to eq 14.98
    end

    it "returns nil as 'NULL'" do
      expect( tester1.send :quote, nil ).to eq %Q|NULL|
    end

    it "will wrap the value in some other character if you pass that" do
      bd = BigDecimal.new("14.98")
      expect( tester1.send :quote, "thing", nil ).to eq %Q|thing|
      expect( tester1.send :quote, "thing", "x" ).to eq %Q|xthingx|
      expect( tester1.send :quote, bd ).to eq 14.98
      expect( tester1.send :quote, "G'Kar", "a" ).to eq %Q|aG'Kaara|
    end

  end


  describe "sql_where(selection)" do

    it "returns an empty string and empty array for an empty selection hash" do
      expect( tester1.send :sql_where, {} ).to eq( [ "", [] ] )
    end


    it "returns valid SQL and unchanged array of values for the selection hash" do
      sql, vals = tester1.send :sql_where, {lambs: "baah", pigs: "moo"}

      expect( sql  ).to match %r|where\s+"lambs"\s*=\s*%s\s+and\s+"pigs"\s*=\s*%s|i
      expect( vals ).to eq( [%q|baah|, %q|moo|] )
    end

  end


  describe "sql_select" do

    it "returns sql plus an array of values" do
      sql, vals = tester1.send( :sql_select, %W|foo bar|, {one: 12} )
      smatch = %r|select\s+"foo",\s*"bar"\s+from\s+"marco"\."polo"\s+where\s+"one"\s*=\s*%s\s*;|i

      expect(sql).to match(smatch)
      expect(vals).to eq( [12] )
    end
      

    it "copes with nil for fields to select *" do
      sql, vals = tester1.send( :sql_select, nil, {one: 12} )
      smatch = %r|select\s+\*\s*from\s+"marco"\."polo"\s*where\s+"one"\s*=\s*%s\s*;|

      expect(sql).to match(smatch)
      expect(vals).to eq( [12] )
    end

    it "copes with one field" do
      sql, vals = tester1.send( :sql_select, "foo", {one: 12} )
      smatch = %r|select\s+"foo"\s+from\s+"marco"\."polo"\s+where\s+"one"\s*=\s*%s\s*;|i

      expect(sql).to match(smatch)
      expect(vals).to eq( [12] )
    end


    it "copes with a selection list" do
      sql, vals = tester1.send( :sql_select, nil, {one: 12, two: 23} )
      smatch = %r|select\s+\*\s*from\s+"marco"\."polo"
                    \s+where\s+"one"\s*=\s*%s\s+and\s+"two"\s*=\s*%s\s*;|ix

      expect(sql).to match(smatch)
      expect(vals).to eq( [12,23] )
    end

    it "copes with no selection list" do
      sql, vals = tester1.send( :sql_select, nil, nil )
      smatch = %r|select\s+\*\s*from\s+"marco"\."polo"\s*;|i

      expect(sql).to match(smatch)
      expect(vals).to eq( [] )
    end

  end

    
  describe "sql_insert" do

    it "raises an exception if there is no column:value hash" do
      expect{ tester1.send :sql_insert, {} }.to raise_error ArgumentError
    end

    it "returns the correct sql plus an array of values" do
      sel = {bada: "bing", bar: "foop"}
      smatch = %r|insert\s+into\s+"marco"\."polo"
                    \s+\(\s*"bada",\s*"bar"\s*\)
                    \s+values\(\s*%s,\s*%s\s*\)
                    \s+returning\s+"foo"\s*;|xi
                                                                                    
      sql, vals = tester1.send :sql_insert, sel

      expect(sql).to match smatch
      expect(vals).to eq( ['bing', 'foop'] )
    end

  end

    
  describe "sql_update" do

    it "raises an exception if there is no column:value hash" do
      expect{ tester1.send :sql_update, {}, {} }.to raise_error ArgumentError
    end

    it "returns the correct SQL and values without a selection hash" do
      fv = {mouse: 14, rat: "meow"}

      smatch = %r|update\s+"marco"\."polo"\s+set
                    \s+"mouse"\s*=\s*%s\s*,
                    \s+"rat"\s*=\s*%s\s*;|xi
                                                                                    
      sql, vals = tester1.send :sql_update, fv, {}

      expect(sql).to match smatch
      expect(vals).to eq( [14, 'meow'] )
    end


    it "returns the correct SQL and values if there is a selection hash" do
      fv = {mouse: 14, rat: "meow"}
      sel = {row: 5, column: true}

      smatch = %r|update\s+"marco"\."polo"\s+set
                    \s+"mouse"\s*=\s*%s\s*,
                    \s+"rat"\s*=\s*%s
                    \s+where\s+"row"\s*=\s*%s\s+and\s+"column"\s*=\s*%s\s*;|xi
                                                                                    
      sql, vals = tester1.send :sql_update, fv, sel

      expect(sql).to match smatch
      expect(vals).to eq( [14, 'meow', 5, true] )
    end

  end

    
  describe "sql_delete(selection)" do

    it "returns the correct SQL and values without a selection hash" do
      sql, vals = tester1.send :sql_delete, {}

      expect(sql).to match %r|delete\s+from\s+"marco"\."polo"\s*;|i
      expect(vals).to eq( [] )
    end


    it "returns the correct SQL and values if there is a selection hash" do
      sql, vals = tester1.send :sql_delete, {alice: 14, ted: "moo"}
      smatch = %r|delete\s+from\s+"marco"\."polo"
                    \s+where\s+"alice"\s*=\s*%s\s+and\s+"ted"\s*=\s*%s\s*;|ix

      expect(sql).to match smatch
      expect(vals).to eq( [14, 'moo'] )
    end

  end

    
  describe "sql_subst" do

    it "raises ArgumentError unless it receives an SQL string" do
      expect{ tester1.send :sql_subst, 19, "foo" }.to raise_error ArgumentError
    end

    it "returns the sql untouched when there are no values" do
      expect( tester1.send :sql_subst, "foo" ).to eq "foo"
    end
    
    it "raises ArgumentError if the sql is blank" do
      expect{ tester1.send :sql_subst, "", 'foo' }.to raise_error ArgumentError
    end

    it "raises ArgumentError if the # of sql markers and the # of values don't match" do
      # (unless we only pass one value, see below)
      expect{ tester1.send :sql_subst, %q|foo %s %s bar %s|, 1, 2 }.to raise_error ArgumentError
      expect{ tester1.send :sql_subst, %q|foo %s bar %s|, 1, 2, 3 }.to raise_error ArgumentError
    end

    it "returns complete SQL for sql with markers and a single value" do
      sql = %q|select * from "foo" where "bar" = %s and "baz" = %s;|
      seq = %q|select * from "foo" where "bar" = 'boing' and "baz" = 'boing';|

      expect( tester1.send :sql_subst, sql, %q|'boing'| ).to eq seq
    end

    it "returns complete SQL for sql with markers and the right number of values in the array" do
      sql = %q|select * from "foo" where "bar" = %s and "baz" = %s;|
      seq = %q|select * from "foo" where "bar" = 'boing' and "baz" = 'bop';|

      expect( tester1.send :sql_subst, sql, %q|'boing'|, %q|'bop'| ).to eq seq
    end

  end

end

