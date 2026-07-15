const q = "wat bot";
const words = q.trim().split(/\s+/);
const where = [];
const params = [];
for (const word of words) {
    where.push('(LOWER(i.name) LIKE ? OR LOWER(COALESCE(i.description, "")) LIKE ? OR LOWER(COALESCE(i.serial_number, "")) LIKE ?)');
    const like = `%${word.toLowerCase()}%`;
    params.push(like, like, like);
}
console.log(where.join(' AND '));
console.log(params);
