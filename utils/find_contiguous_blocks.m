function blocks = find_contiguous_blocks(mask)
% FIND_CONTIGUOUS_BLOCKS
% Toolbox-free replacement for bwconncomp (1D logical)

mask = mask(:)';
d = diff([false mask false]);
starts = find(d == 1);
ends   = find(d == -1) - 1;

blocks = [starts(:), ends(:)];
end
