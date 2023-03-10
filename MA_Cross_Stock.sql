USE [ncudatabase]
GO
/****** Object:  StoredProcedure [dbo].[MA_Cross]    Script Date: 2023/2/28 下午 01:43:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[MA_Cross]
	@MA1_input varchar(10),	
	@MA2_input varchar(10),
	@trend_input int,-- 1:cross up,-1:cross down
	@duration int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @date date
	DECLARE @id varchar(10)
	DECLARE @sqlText nvarchar(1000)
	DECLARE @ParmDefinition nvarchar(500) 
	SELECT @date=max(date) from stock_data 

	DECLARE @stock_code varchar(10)
	DECLARE @i int
	DECLARE @MA1_value real
	DECLARE @MA2_value real
	DECLARE @MA1_prevalue real
	DECLARE @MA2_prevalue real
	CREATE Table #stock_temp(
		id int IDENTITY(1,1),
		date date Not Null,
		stock_code varchar(10) Not Null,
		MA_1 real Not null,
		MA_2 real Not null
	)
	CREATE Table #stock(
		stock_code varchar(10)
	)

	declare cur CURSOR LOCAL for
    select distinct stock_code from stock_data

	open cur

	fetch next from cur into @id

	WHILE @@FETCH_STATUS = 0 BEGIN
		--execute your sproc on each row

		--把某一支股票X日前的MA1與MA2資料抓到#stock_temp表上
		SET @sqlText = N'SELECT date, stock_code,' + @MA1_input + ',' + @MA2_input + 
		' FROM dbo.stock_data WHERE date in (SELECT date FROM find_date( @date_input, @duration_input)) AND stock_code = @id_input order by date'
		SET @ParmDefinition = N'@date_input date, @duration_input int, @id_input varchar(10)';
		DELETE FROM #stock_temp--把前一支股票資料刪除
		INSERT #stock_temp exec sp_executesql @sqlText, @ParmDefinition, @date_input=@date, @duration_input=@duration, @id_input=@id
		--紀錄第一筆資料並刪除不做計算
		SELECT TOP(1) @i= id, @MA1_prevalue = MA_1, @MA2_prevalue = MA_2 FROM #stock_temp
		DELETE #stock_temp WHERE id = @i
		--當#stock_temp還有資料時
		WHILE EXISTS(SELECT * FROM #stock_temp)
			BEGIN
				--把那天資料抓出來
				SELECT TOP(1) @i= id, @stock_code = stock_code, @MA1_value = MA_1, @MA2_value = MA_2 FROM #stock_temp
				--並與前一天的資料作比對且符合上/下穿
				IF (@trend_input=1 AND @MA1_prevalue < @MA2_prevalue AND @MA1_value > @MA2_value) OR
					(@trend_input=-1 AND @MA1_prevalue > @MA2_prevalue AND @MA1_value < @MA2_value)
					BEGIN
						--符合條件insert進#stock並break
						INSERT INTO #stock (stock_code)
						VALUES(@stock_code)
						break
					END
				--更新prevalue並刪除這一天資料
				SET @MA1_prevalue=@MA1_value
				SET @MA2_prevalue=@MA2_value
				DELETE #stock_temp WHERE id = @i
			END

		fetch next from cur into @id
	END

	close cur
	deallocate cur
	SELECT * FROM #stock
END
