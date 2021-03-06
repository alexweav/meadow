import React from "react";
import PropTypes from "prop-types";

const IngestSheetErrorsState = ({ validations }) => {
  const rowHasErrors = object =>
    object && object.errors && object.errors.length > 0;
  return (
    <>
      <table>
        <caption>Ingest sheet validation row errors</caption>
        <thead>
          <tr>
            <th>Row #</th>
            <th>Status</th>
            <th>Content</th>
            <th>Errors</th>
          </tr>
        </thead>
        <tbody>
          {validations.map(object => (
            <tr key={object.row}>
              <td>{object && object.row}</td>
              <td>{object && object.state}</td>
              <td>
                {object && object.fields.map(field => field.value).join("; ")}
              </td>
              <td>
                {rowHasErrors(object)
                  ? object.errors
                      .map(({ _field, message }, index) => message)
                      .join(", ")
                  : ""}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
};

IngestSheetErrorsState.propTypes = {
  validations: PropTypes.arrayOf(PropTypes.object)
};

export default IngestSheetErrorsState;
