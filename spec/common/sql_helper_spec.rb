require 'pod4/interface'
require 'pod4/sql_helper'

class SQLHelperTester < Pod4::Interface
  include SQLHelper

end


describe SQLHelperTester do
    
  describe "sql_select(fields, selection)" do
  end

    
  describe "sql_insert(id_fld, fldsValues)" do
  end

    
  describe "sql_update(fldsValues, selection)" do
  end

    
  describe "sql_delete(selection)" do
  end

    
  describe "sql_where(selection)" do
  end

    
  describe "quoted_table" do
  end

    
  describe "quote_field(fld)" do
  end

    
  describe "quote(fld)" do
  end

    
  describe "placeholder" do
  end

    
  describe "sql_subst(sql, array)" do
  end

end

