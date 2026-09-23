-- 可选：把原来 Excel 里的 4 个名字和 7 件物品导入（只在 items 表为空时插入，重复运行不会加两遍）
update public.settings set room = '33-206', cur = '$', roster = '["Simon","Gary","Harry","Yuluo"]'::jsonb where id = 'main';

insert into public.items (no, name, area, qty, priority, status, note)
select * from (values
  (1, '公共拖鞋',   '玄关',   6, '高', '待购买', '一人一双，额外两双客用'),
  (2, '拖把',       '客厅',   1, '高', '待购买', ''),
  (3, '扫把套装',   '客厅',   1, '高', '待购买', ''),
  (4, '进门脚垫',   '玄关',   1, '中', '待购买', ''),
  (5, '洗碗机球',   '厨房',   1, '高', '待购买', ''),
  (6, '浴帘及挂钩', '卫生间', 1, '中', '待购买', ''),
  (7, '浴室拖鞋架', '卫生间', 1, '中', '待购买', '')
) as v(no, name, area, qty, priority, status, note)
where not exists (select 1 from public.items);
