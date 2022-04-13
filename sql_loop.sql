declare @idColumn int

select @idColumn = min( TableID ) from Table

while @idColumn is not null
begin
    /*
        Do all the stuff that you need to do
    */
    select @idColumn = min( TableID ) from Table where TableID > @idColumn
end
