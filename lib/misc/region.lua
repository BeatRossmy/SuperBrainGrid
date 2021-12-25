Region = function () return {
  start = nil,
  out = nil,
  
  set = function (self,i)
    if not self.start then
      self.start,self.out = i,i
    elseif i<self.start then 
      self.start = i
    elseif i>self.out then
      self.out = i
    elseif i==self.start then
      self.start = ((self.out and self.out~=self.start) and self.out or nil)
      self.out = self.start
    elseif i==self.out then
      self.out = self.start
    end
    if self.start and self.out and self.start>self.out then
      local _s = self.start
      self.start = self.out
      self.out = _s
    end
  end,
  
  is_set = function (self)
    return self.start~=nil
  end,
  
  wrap = function (self, v, r1, r2)
    if not self:is_set() then
      return (r1 and r2) and util.wrap(v,r1,r2) or v
    end
    return util.wrap(v,self.start,self.out)
  end,
  
  --[[iterator = function (self)
    local index = self.start and (0+self.start) or 0
    local count = self.out and (0+self.out) or 0
    print(index,count)
    return function ()
      index = index + 1
      if index <= count then
        return index
      end
    end
  end,--]]
  
  print = function (self)
    if start and out then
      print("region:",start,out)
    else
      print("region empty")
    end
  end
} end